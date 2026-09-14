import AVFAudio
import Foundation

struct SystemVoiceMetadata: Sendable {
    let name: String
    let language: String
    let isPersonal: Bool
    let isNovelty: Bool
    let quality: VoiceQuality
}

/// The production speech boundary. `say` is the only speech synthesizer; Apple
/// audio frameworks inspect output and capture genuine Personal Voice playback.
@MainActor public final class SystemSpeech: SpeechSystem {
    private let playback = SayProcess()
    private let discovery = SayProcess()
    private let personalVoice = PersonalVoiceAccess()
    private let capture = PersonalVoiceCapture()
    private var isSpeaking = false
    private var cachedCapabilities: SpeechCapabilities?

    public init() {}

    public func voices() async throws -> [Voice] {
        let listing = try await discovery.run(arguments: ["-v", "?"]).checked()
        let catalog = SayCatalog.voices(from: listing)
        let metadata = AVSpeechSynthesisVoice.speechVoices().map {
            SystemVoiceMetadata(
                name: $0.name,
                language: $0.language,
                isPersonal: $0.voiceTraits.contains(.isPersonalVoice),
                isNovelty: $0.voiceTraits.contains(.isNoveltyVoice),
                quality: Self.quality(metadata: $0)
            )
        }
        // AVSpeechSynthesizer provides authorization/traits only. A voice must
        // also be advertised by say before we allow it into the speech workflow.
        return Self.merge(catalog: catalog, metadata: metadata)
    }

    static func merge(catalog: [Voice], metadata: [SystemVoiceMetadata]) -> [Voice] {
        catalog.compactMap { voice in
            let matches = metadata.filter { Self.matches(voice, metadata: $0) }
            guard !matches.isEmpty else {
                return Voice(id: voice.id, name: voice.name, language: voice.language,
                             quality: Self.quality(name: voice.name, metadataQuality: nil))
            }
            // `say` exposes only display name and locale. If those identify both
            // a Personal Voice and an ordinary Voice, selecting either is unsafe.
            guard Set(matches.map(\.isPersonal)).count == 1 else { return nil }
            return Voice(
                id: voice.id,
                name: voice.name,
                language: voice.language,
                isPersonal: matches[0].isPersonal,
                isNovelty: matches.contains(where: \.isNovelty),
                quality: Self.quality(name: voice.name, metadataQuality: matches.map(\.quality).max())
            )
        }
    }

    private static func matches(_ voice: Voice, metadata: SystemVoiceMetadata) -> Bool {
        let localeMatches = voice.language.replacingOccurrences(of: "_", with: "-")
            .caseInsensitiveCompare(metadata.language) == .orderedSame
        let nameMatches = voice.name == metadata.name || voice.name.hasPrefix(metadata.name + " (")
        return localeMatches && nameMatches
    }

    private static func quality(name: String, metadataQuality: VoiceQuality?) -> VoiceQuality {
        if name.localizedCaseInsensitiveContains("(Premium)") || metadataQuality == .premium {
            return .premium
        }
        if name.localizedCaseInsensitiveContains("(Enhanced)") || metadataQuality == .enhanced {
            return .enhanced
        }
        return metadataQuality ?? .standard
    }

    private static func quality(metadata: AVSpeechSynthesisVoice) -> VoiceQuality {
        if metadata.quality == .premium { return .premium }
        if metadata.quality == .enhanced
            || metadata.identifier.localizedCaseInsensitiveContains("siri") {
            return .enhanced
        }
        if metadata.identifier.contains(".voice.compact.") { return .compact }
        if metadata.identifier.contains(".eloquence.")
            || metadata.identifier.contains(".speech.synthesis.voice.") { return .legacy }
        return .standard
    }

    public func capabilities() async throws -> SpeechCapabilities {
        if let cachedCapabilities { return cachedCapabilities }
        let result = try await SayCapabilityDiscovery.discover(using: discovery)
        cachedCapabilities = result
        return result
    }

    public func authorization() -> PersonalVoiceAuthorization { personalVoice.authorization() }

    public func requestAuthorization() async -> PersonalVoiceAuthorization {
        cachedCapabilities = nil
        return await personalVoice.requestAuthorization()
    }

    public func speak(_ request: SpeechRequest) async throws {
        guard !isSpeaking else { throw SpeechError.busy }
        isSpeaking = true
        defer { isSpeaking = false }
        try requireAuthorization(for: request)
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("document.txt")
        try SayArguments.inputText(for: request).write(to: input, atomically: true, encoding: .utf8)
        let arguments = try SayArguments.make(for: request, input: input)
        if request.destination != nil, request.settings.voice?.isPersonal != true {
            // Validate the complete codec/channel/bitrate combination against the
            // installed converter using empty input before synthesizing user text.
            let probe = SpeechRequest(text: "", settings: request.settings,
                                      destination: directory.appendingPathComponent("probe.\(request.output.container.rawValue)"),
                                      output: request.output)
            let probeArguments = try SayArguments.make(for: probe, input: URL(fileURLWithPath: "/dev/null"))
            _ = try await playback.run(arguments: probeArguments).checked()
        }
        let result = try await playback.run(arguments: arguments)
        if request.destination != nil, request.settings.voice?.isPersonal == true,
           let unavailable = PersonalVoiceNativeOutput.unavailable(from: result) {
            throw unavailable
        }
        _ = try result.checked()
        if let destination = request.destination {
            guard FileManager.default.fileExists(atPath: destination.path) else {
                if request.settings.voice?.isPersonal == true {
                    throw SpeechError.nativeOutputUnavailable("The system completed playback without producing an audio file.")
                }
                throw SpeechError.emptyAudio
            }
            let file: AVAudioFile
            do { file = try AVAudioFile(forReading: destination) } catch {
                if request.settings.voice?.isPersonal == true {
                    throw SpeechError.nativeOutputUnavailable("The system completed without producing a readable Personal Voice audio file.")
                }
                throw error
            }
            guard file.length > 0 else {
                if request.settings.voice?.isPersonal == true {
                    throw SpeechError.nativeOutputUnavailable("The system produced no Personal Voice audio frames.")
                }
                throw SpeechError.emptyAudio
            }
            if request.settings.voice?.isPersonal == true, try !containsSignal(file) {
                throw SpeechError.nativeOutputUnavailable("The system produced a silent Personal Voice file without rendered speech.")
            }
        }
    }

    public func capturePersonalVoice(_ request: SpeechRequest) async throws {
        guard !isSpeaking else { throw SpeechError.busy }
        guard request.settings.voice?.isPersonal == true, let destination = request.destination else {
            throw SpeechError.invalidSettings("Personal Voice capture requires a Personal Voice and an output destination.")
        }
        guard request.output.container == .caf else {
            throw SpeechError.invalidSettings("Personal Voice capture requires a temporary CAF destination before final conversion.")
        }
        try requireAuthorization(for: request)
        isSpeaking = true
        defer { isSpeaking = false }
        var settings = request.settings
        settings.outputDevice = nil
        settings.networkService = nil
        let playbackRequest = SpeechRequest(text: request.text, settings: settings)
        let arguments = try SayArguments.make(for: playbackRequest, input: URL(fileURLWithPath: "-"))
        // A URL cannot represent say's stdin sentinel: remove the input file
        // pair so the child waits on its private pipe until the tap is active.
        let inputIndex = arguments.firstIndex(of: "-f")!
        var captureArguments = arguments
        captureArguments.removeSubrange(inputIndex...(inputIndex + 1))
        do {
            let result = try await playback.run(arguments: captureArguments,
                                                input: Data(try SayArguments.inputText(for: request).utf8)) { [capture] pid in
                try await capture.start(processID: pid, destination: destination)
            }
            _ = try result.checked()
            try capture.finish()
        } catch {
            capture.cancel()
            throw error
        }
    }

    public func stop() {
        playback.stop()
        capture.cancel()
    }

    private func requireAuthorization(for request: SpeechRequest) throws {
        if request.settings.voice?.isPersonal == true, authorization() != .authorized {
            throw SpeechError.invalidSettings("Allow Personal Voice access before using this Voice.")
        }
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                               attributes: [.posixPermissions: 0o700])
        return directory
    }

    private func containsSignal(_ file: AVAudioFile) throws -> Bool {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4096) else {
            throw SpeechError.nativeOutputUnavailable("The system did not provide readable Personal Voice PCM.")
        }
        while file.framePosition < file.length {
            try file.read(into: buffer)
            guard let channels = buffer.floatChannelData else {
                throw SpeechError.nativeOutputUnavailable("The system did not provide floating-point Personal Voice PCM.")
            }
            for channel in 0..<Int(buffer.format.channelCount) {
                for frame in 0..<Int(buffer.frameLength) {
                    let sample = channels[channel][frame * buffer.stride]
                    if !sample.isFinite { throw SpeechError.emptyAudio }
                    if sample != 0 { return true }
                }
            }
        }
        return false
    }
}

enum PersonalVoiceNativeOutput {
    static func unavailable(from result: SayProcessResult) -> SpeechError? {
        guard result.status != 0 else { return nil }
        let diagnostic = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        return .nativeOutputUnavailable(diagnostic.isEmpty
            ? "The system rejected direct Personal Voice file output."
            : diagnostic)
    }
}
