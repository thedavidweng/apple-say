import AVFAudio
import AudioToolbox
import AppleSayAudioBridge
import Foundation

/// Streams PCM in bounded blocks: long intentional gaps never allocate a timeline-sized buffer.
enum AudioFiles {
    static let sampleRate = 44_100.0
    static let blockFrames: UInt32 = 4096

    static func duration(of url: URL) throws -> Double {
        let file = try AVAudioFile(forReading: url)
        guard file.length > 0 else { throw SpeechError.emptyAudio }
        return Double(file.length) / file.processingFormat.sampleRate
    }

    static func validate(_ url: URL, settings: ExportSettings) throws {
        let file = try AVAudioFile(forReading: url)
        guard file.length > 0 else { throw SpeechError.emptyAudio }

        var audioFile: AudioFileID?
        try check(AudioFileOpenURL(url as CFURL, .readPermission, 0, &audioFile))
        guard let audioFile else { throw SpeechError.emptyAudio }
        defer { AudioFileClose(audioFile) }

        var actualType = AudioFileTypeID()
        var typeSize = UInt32(MemoryLayout<AudioFileTypeID>.size)
        try check(AudioFileGetProperty(audioFile, kAudioFilePropertyFileFormat, &typeSize, &actualType))
        guard actualType == fileType(settings.container) else {
            throw SpeechError.processFailed("The exported audio container does not match the selected format.")
        }

        let actual = file.fileFormat.streamDescription.pointee
        if let channels = settings.channels, actual.mChannelsPerFrame != UInt32(channels) {
            throw SpeechError.processFailed("The exported audio channel count does not match the selected setting.")
        }
        let expected = try outputFormat(settings, channels: actual.mChannelsPerFrame)
        guard actual.mFormatID == expected.mFormatID else {
            throw SpeechError.processFailed("The exported audio data format does not match the selected setting.")
        }
        if expected.mFormatID == kAudioFormatLinearPCM {
            let relevantFlags = AudioFormatFlags(kAudioFormatFlagIsFloat | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian)
            guard actual.mBitsPerChannel == expected.mBitsPerChannel,
                  actual.mFormatFlags & relevantFlags == expected.mFormatFlags & relevantFlags else {
                throw SpeechError.processFailed("The exported PCM representation does not match the selected setting.")
            }
        }
    }

    static func assemble(_ clips: [(url: URL, start: Double)], to destination: URL, endingAt: Double) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let output = try AVAudioFile(forWriting: destination, settings: format.settings)
        let silence = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: blockFrames)!
        memset(silence.floatChannelData![0], 0, Int(blockFrames) * MemoryLayout<Float>.size)
        var cursor: Int64 = 0
        for clip in clips {
            try Task.checkCancellation()
            let start = Int64((clip.start * sampleRate).rounded())
            guard start >= cursor else { throw SpeechError.invalidSettings("Audio overlaps on the requested timeline.") }
            while cursor < start {
                try Task.checkCancellation()
                silence.frameLength = UInt32(min(Int64(blockFrames), start - cursor))
                try output.write(from: silence)
                cursor += Int64(silence.frameLength)
            }
            let source = try AVAudioFile(forReading: clip.url)
            let buffer = AVAudioPCMBuffer(pcmFormat: source.processingFormat, frameCapacity: blockFrames)!
            while source.framePosition < source.length {
                try Task.checkCancellation()
                try source.read(into: buffer)
                try output.write(from: buffer)
                cursor += Int64(buffer.frameLength)
            }
        }
        let end = Int64((endingAt * sampleRate).rounded())
        while cursor < end {
            try Task.checkCancellation()
            silence.frameLength = UInt32(min(Int64(blockFrames), end - cursor))
            try output.write(from: silence)
            cursor += Int64(silence.frameLength)
        }
    }

    static func normalize(_ source: URL, to destination: URL) throws {
        var settings = ExportSettings(container: .caf)
        settings.dataFormat = "LEF32"
        settings.channels = 1
        try convert(source, to: destination, settings: settings)
    }

    /// Verifies the exact system-converter combination with generated PCM before
    /// Timed Text or Personal Voice synthesis begins.
    static func preflight(_ settings: ExportSettings) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.caf")
        let destination = directory.appendingPathComponent("output.\(settings.container.rawValue)")
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let file = try AVAudioFile(forWriting: source, settings: format.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 256)!
        buffer.frameLength = 256
        for frame in 0..<Int(buffer.frameLength) { buffer.floatChannelData![0][frame] = 0.1 }
        try file.write(from: buffer)
        try convert(source, to: destination, settings: settings)
        _ = try duration(of: destination)
    }

    static func convert(_ source: URL, to destination: URL, settings: ExportSettings) throws {
        var input: ExtAudioFileRef?
        try check(ExtAudioFileOpenURL(source as CFURL, &input))
        guard let input else { throw SpeechError.emptyAudio }
        defer { ExtAudioFileDispose(input) }
        let channels = UInt32(settings.channels ?? 1)
        var target = try outputFormat(settings, channels: channels)
        var output: ExtAudioFileRef?
        try check(ExtAudioFileCreateWithURL(destination as CFURL, fileType(settings.container), &target, nil,
                                          AudioFileFlags.eraseFile.rawValue, &output))
        guard let output else { throw SpeechError.emptyAudio }
        defer { ExtAudioFileDispose(output) }
        var client = AudioStreamBasicDescription(mSampleRate: sampleRate, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4 * channels, mFramesPerPacket: 1, mBytesPerFrame: 4 * channels,
            mChannelsPerFrame: channels, mBitsPerChannel: 32, mReserved: 0)
        let size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check(ExtAudioFileSetProperty(input, kExtAudioFileProperty_ClientDataFormat, size, &client))
        try check(ExtAudioFileSetProperty(output, kExtAudioFileProperty_ClientDataFormat, size, &client))
        try configureConverter(output, settings: settings)
        var samples = [Float](repeating: 0, count: Int(blockFrames * channels))
        try samples.withUnsafeMutableBytes { bytes in
            var list = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: channels,
                mDataByteSize: UInt32(bytes.count), mData: bytes.baseAddress))
            while true {
                try Task.checkCancellation()
                var count = blockFrames
                list.mBuffers.mDataByteSize = UInt32(bytes.count)
                try check(ExtAudioFileRead(input, &count, &list))
                if count == 0 { break }
                try check(ExtAudioFileWrite(output, count, &list))
            }
        }
    }

    private static func configureConverter(_ file: ExtAudioFileRef, settings: ExportSettings) throws {
        guard settings.bitRate != nil || settings.quality != nil else { return }
        var converter: AudioConverterRef?
        var size = UInt32(MemoryLayout<AudioConverterRef?>.size)
        try check(ExtAudioFileGetProperty(file, kExtAudioFileProperty_AudioConverter, &size, &converter))
        guard let converter else { throw SpeechError.invalidSettings("These conversion settings do not apply to this output.") }
        if let rate = settings.bitRate {
            var value = UInt32(rate)
            try check(AudioConverterSetProperty(converter, kAudioConverterEncodeBitRate, 4, &value))
        }
        if let quality = settings.quality {
            var value = UInt32(quality)
            try check(AudioConverterSetProperty(converter, kAudioConverterCodecQuality, 4, &value))
        }
        // Commit the converter's concrete settings so the file header and encoder agree.
        // The C boundary is needed because this property contains a CFArrayRef pointer.
        try check(AppleSayCommitExtAudioFileConverter(file, converter))
    }

    private static func outputFormat(_ settings: ExportSettings, channels: UInt32) throws -> AudioStreamBasicDescription {
        let token = settings.dataFormat ?? (settings.container == .m4a ? "aac" : settings.container == .aiff ? "BEI16" : "LEI16")
        let regex = try! NSRegularExpression(pattern: #"^(BE|LE)?([IF])(8|16|24|32|64)$"#)
        let match = regex.firstMatch(in: token, range: NSRange(token.startIndex..., in: token))
        if let match {
            let value = token as NSString
            let bits = UInt32(value.substring(with: match.range(at: 3)))!
            let isFloat = value.substring(with: match.range(at: 2)) == "F"
            var flags = kAudioFormatFlagIsPacked | (isFloat ? kAudioFormatFlagIsFloat : kAudioFormatFlagIsSignedInteger)
            if match.range(at: 1).location != NSNotFound && value.substring(with: match.range(at: 1)) == "BE" {
                flags |= kAudioFormatFlagIsBigEndian
            }
            return AudioStreamBasicDescription(mSampleRate: sampleRate, mFormatID: kAudioFormatLinearPCM,
                mFormatFlags: flags, mBytesPerPacket: bits / 8 * channels, mFramesPerPacket: 1,
                mBytesPerFrame: bits / 8 * channels, mChannelsPerFrame: channels, mBitsPerChannel: bits, mReserved: 0)
        }
        guard token.utf8.count <= 4 else { throw SpeechError.invalidSettings("Unsupported audio data format: \(token)") }
        let code = token.padding(toLength: 4, withPad: " ", startingAt: 0).utf8.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        var format = AudioStreamBasicDescription()
        format.mSampleRate = sampleRate; format.mFormatID = code; format.mChannelsPerFrame = channels
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, nil, &size, &format))
        return format
    }

    private static func fileType(_ container: AudioContainer) -> AudioFileTypeID {
        switch container {
        case .aiff: kAudioFileAIFFType
        case .caf: kAudioFileCAFType
        case .wav: kAudioFileWAVEType
        case .m4a: kAudioFileM4AType
        }
    }

    private static func check(_ status: OSStatus) throws {
        guard status == noErr else { throw SpeechError.processFailed("The system audio converter failed (\(status)).") }
    }
}
