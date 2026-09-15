import AudioToolbox
import CoreAudio
import Foundation

/// Captures only the launched `say` process through public Core Audio APIs.
/// A speech-service process that macOS does not attribute to `say` is intentionally
/// not captured: widening the tap could record unrelated speech or application audio.
@MainActor public final class PersonalVoiceCapture {
    private var session: ProcessAudioTap?
    private var generation = 0

    public init() {}

    /// Invoke after launching `say`, before releasing its text through standard input.
    public func start(processID: pid_t, destination: URL) async throws {
        guard #available(macOS 14.2, *) else {
            throw SpeechError.captureUnavailable("This system does not provide the required process audio capture API.")
        }
        guard session == nil else {
            throw SpeechError.captureFailed("A previous process audio tap could not be released. Restart Apple Say before retrying Export.")
        }
        generation += 1
        let attempt = generation
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectHasProperty(AudioObjectID(kAudioObjectSystemObject), &address) else {
            throw SpeechError.captureUnavailable("macOS does not expose audio process identification.")
        }
        // `say` must have registered its audio client before we release any text.
        // Starting playback first and attaching later would silently lose initial speech.
        let deadline = ContinuousClock.now + .seconds(2)
        var processObject = AudioObjectID(kAudioObjectUnknown)
        while processObject == kAudioObjectUnknown && ContinuousClock.now < deadline {
            try Task.checkCancellation()
            guard generation == attempt else { throw CancellationError() }
            var pid = processID
            var size = UInt32(MemoryLayout<AudioObjectID>.size)
            let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address,
                                                   UInt32(MemoryLayout<pid_t>.size), &pid, &size, &processObject)
            guard status == noErr else {
                throw SpeechError.captureUnavailable("macOS could not identify the speech audio process (\(status)).")
            }
            if processObject == kAudioObjectUnknown { try await Task.sleep(for: .milliseconds(20)) }
        }
        try Task.checkCancellation()
        guard generation == attempt else { throw CancellationError() }
        guard processObject != kAudioObjectUnknown else {
            let message = "macOS did not expose the say audio process before playback. Recording cannot begin without risking missing speech."
            throw SpeechError.captureUnavailable(message)
        }
        let tap = ProcessAudioTap()
        do {
            try tap.start(processObject: processObject, destination: destination)
            session = tap
        } catch {
            guard tap.cancel() else {
                session = tap
                let message = "Core Audio setup failed and its process tap could not be fully released. Restart Apple Say before retrying Export."
                throw SpeechError.captureFailed(message)
            }
            throw error
        }
    }

    public func finish() throws {
        guard let session else { throw SpeechError.captureFailed("No audio capture is active.") }
        try session.finish()
        self.session = nil
    }

    public func cancel() {
        generation += 1
        if session?.cancel() == true { session = nil }
    }
}

private final class ProcessAudioTap: @unchecked Sendable {
    private let queue = DispatchQueue(label: "AppleSay.PersonalVoiceCapture")
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private var ioProc: AudioDeviceIOProcID?
    private var isRunning = false
    private var file: ExtAudioFileRef?
    private var destination: URL?
    private var bytesPerFrame: UInt32 = 0
    private var writeStatus: OSStatus = noErr
    private var hasSignal = false
    private var framesWritten: UInt64 = 0

    @available(macOS 14.2, *)
    func start(processObject: AudioObjectID, destination: URL) throws {
        self.destination = destination
        let description = CATapDescription(stereoMixdownOfProcesses: [processObject])
        description.name = "Apple Say Personal Voice Export"
        description.isPrivate = true
        description.muteBehavior = .mutedWhenTapped
        try require(AudioHardwareCreateProcessTap(description, &tapID), "create a process audio tap")

        var address = AudioObjectPropertyAddress(mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try require(AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &format), "read the captured PCM format")
        guard format.mFormatID == kAudioFormatLinearPCM,
              format.mFormatFlags & kAudioFormatFlagIsFloat != 0,
              format.mBitsPerChannel == 32, format.mBytesPerFrame > 0,
              format.mSampleRate > 0 else {
            throw SpeechError.captureUnavailable("The process tap did not expose supported 32-bit floating-point PCM.")
        }
        bytesPerFrame = format.mBytesPerFrame
        // A tap may expose planar PCM; the CAF stores interleaved PCM while the
        // extended audio file writer accepts the tap's original client layout.
        var fileFormat = format
        fileFormat.mFormatFlags &= ~kAudioFormatFlagIsNonInterleaved
        fileFormat.mBytesPerFrame = 4 * format.mChannelsPerFrame
        fileFormat.mBytesPerPacket = fileFormat.mBytesPerFrame
        try require(ExtAudioFileCreateWithURL(destination as CFURL, kAudioFileCAFType, &fileFormat,
                                              nil, AudioFileFlags.eraseFile.rawValue, &file), "create the captured audio file")
        guard let file else { throw SpeechError.captureFailed("macOS did not create an audio file.") }
        try require(ExtAudioFileSetProperty(file, kExtAudioFileProperty_ClientDataFormat, size, &format), "configure captured PCM")
        // Prime the asynchronous writer off the real-time audio callback.
        try require(ExtAudioFileWriteAsync(file, 0, nil), "prepare the audio writer")

        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Apple Say Personal Voice Capture",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapUIDKey: description.uuid.uuidString,
                kAudioSubTapDriftCompensationKey: true
            ]]
        ]
        try require(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &deviceID), "create a private capture device")
        try require(AudioDeviceCreateIOProcIDWithBlock(&ioProc, deviceID, queue) { [self] _, input, _, _, _ in
            record(input)
        }, "attach the PCM recorder")
        try require(
            AudioDeviceStart(deviceID, ioProc),
            "start audio capture; allow Apple Say in System Settings → Privacy & Security → Screen & System Audio Recording"
        )
        isRunning = true
    }

    private func record(_ input: UnsafePointer<AudioBufferList>) {
        guard writeStatus == noErr, let file else { return }
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        guard let first = buffers.first else { return }
        let frames = first.mDataByteSize / bytesPerFrame
        guard frames > 0 else { return }
        for buffer in buffers {
            guard let data = buffer.mData else { continue }
            let samples = UnsafeBufferPointer(start: data.assumingMemoryBound(to: Float.self),
                                              count: Int(buffer.mDataByteSize) / MemoryLayout<Float>.size)
            if samples.contains(where: { !$0.isFinite }) {
                writeStatus = kAudio_ParamError
                return
            }
            if samples.contains(where: { $0 != 0 }) { hasSignal = true }
        }
        writeStatus = ExtAudioFileWriteAsync(file, frames, input)
        framesWritten += UInt64(frames)
    }

    func finish() throws {
        let closeStatus = close()
        guard writeStatus == noErr, closeStatus == noErr else {
            removePartialFile()
            throw SpeechError.captureFailed("macOS could not finish writing captured PCM (\(writeStatus == noErr ? closeStatus : writeStatus)).")
        }
        guard framesWritten > 0, hasSignal else {
            removePartialFile()
            let message = "The selected speech process produced no capturable audio. Check Apple Say’s system audio recording permission. " +
                "macOS may isolate Personal Voice playback from this process."
            throw SpeechError.captureUnavailable(message)
        }
    }

    func cancel() -> Bool {
        let status = close()
        removePartialFile()
        return status == noErr
    }

    private func close() -> OSStatus {
        var status = noErr
        func record(_ result: OSStatus) {
            if status == noErr, result != noErr { status = result }
        }
        if let ioProc {
            if isRunning {
                let stopStatus = AudioDeviceStop(deviceID, ioProc)
                record(stopStatus)
                if stopStatus == noErr { isRunning = false }
            }
            let destroyStatus = AudioDeviceDestroyIOProcID(deviceID, ioProc)
            record(destroyStatus)
            if destroyStatus == noErr { self.ioProc = nil }
        }
        guard ioProc == nil else { return status }
        queue.sync {}
        if let file {
            let disposeStatus = ExtAudioFileDispose(file)
            record(disposeStatus)
            if disposeStatus == noErr { self.file = nil }
        }
        if deviceID != kAudioObjectUnknown {
            let destroyStatus = AudioHardwareDestroyAggregateDevice(deviceID)
            record(destroyStatus)
            if destroyStatus == noErr { deviceID = AudioObjectID(kAudioObjectUnknown) }
        }
        if tapID != kAudioObjectUnknown {
            if #available(macOS 14.2, *) {
                let destroyStatus = AudioHardwareDestroyProcessTap(tapID)
                record(destroyStatus)
                if destroyStatus == noErr { tapID = AudioObjectID(kAudioObjectUnknown) }
            }
        }
        return status
    }

    private func removePartialFile() {
        if let destination { try? FileManager.default.removeItem(at: destination) }
    }

    private func require(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else {
            throw SpeechError.captureUnavailable("Could not \(operation) (\(status)).")
        }
    }
}
