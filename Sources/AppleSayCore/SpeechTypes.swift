import Foundation

public struct Voice: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let language: String
    public let isPersonal: Bool
    public init(id: String, name: String, language: String, isPersonal: Bool = false) {
        self.id = id; self.name = name; self.language = language; self.isPersonal = isPersonal
    }
}

public enum VoiceLanguage {
    /// Matches the user's ordered macOS language preferences to a locale exposed
    /// by `say`, preferring the exact region before a same-language variant.
    public static func systemDefault(among voices: [Voice],
                                     preferredLanguages: [String] = Locale.preferredLanguages) -> String? {
        var available: [String] = []
        for voice in voices where !available.contains(voice.language) { available.append(voice.language) }
        for preference in preferredLanguages {
            if let exact = available.first(where: { normalized($0) == normalized(preference) }) {
                return exact
            }
            let preferred = components(preference)
            if let regional = available.first(where: {
                let candidate = components($0)
                return candidate.language == preferred.language && candidate.region == preferred.region
            }) {
                return regional
            }
            if let language = available.first(where: { components($0).language == preferred.language }) {
                return language
            }
        }
        return nil
    }

    private static func normalized(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "_", with: "-").lowercased()
    }

    private static func components(_ identifier: String) -> (language: String?, region: String?) {
        let locale = Locale(identifier: identifier.replacingOccurrences(of: "_", with: "-"))
        return (locale.language.languageCode?.identifier, locale.region?.identifier)
    }
}

public enum PersonalVoiceAuthorization: String, Sendable {
    case notDetermined, denied, restricted, authorized, unsupported
}

public struct SpeechSettings: Equatable, Sendable {
    public var voice: Voice?
    public var speed: Int = 175
    /// nil preserves the selected Voice's natural baseline pitch (Hz otherwise).
    public var pitch: Double?
    public var outputDevice: String?
    public var networkService: String?
    public init(voice: Voice? = nil) { self.voice = voice }
}

public enum AudioContainer: String, CaseIterable, Identifiable, Sendable {
    case aiff, caf, wav, m4a
    public var id: String { rawValue }
    public var title: String { self == .wav ? "WAVE" : rawValue.uppercased() }
    public var sayFormat: String {
        switch self { case .aiff: "AIFF"; case .caf: "caff"; case .wav: "WAVE"; case .m4a: "m4af" }
    }
    public var defaultDataFormat: String {
        switch self { case .aiff: "BEI16"; case .caf, .wav: "LEI16"; case .m4a: "aac" }
    }
}

public struct ExportSettings: Equatable, Sendable {
    public var container: AudioContainer = .aiff
    public var dataFormat: String?
    public var channels: Int?
    public var bitRate: Int?
    public var quality: Int?
    public init(container: AudioContainer = .aiff) { self.container = container }
}

public struct AudioDataCapability: Equatable, Sendable {
    public var dataFormat: String
    public var channels: [Int]
    public var bitRates: [Int]
    public var supportsQuality: Bool
    public init(dataFormat: String, channels: [Int], bitRates: [Int] = [], supportsQuality: Bool = false) {
        self.dataFormat = dataFormat; self.channels = channels; self.bitRates = bitRates
        self.supportsQuality = supportsQuality
    }
}

public struct OutputCapability: Equatable, Sendable {
    public var container: AudioContainer
    public var profiles: [AudioDataCapability]
    public init(container: AudioContainer, profiles: [AudioDataCapability]) {
        self.container = container; self.profiles = profiles
    }
    public var defaultProfile: AudioDataCapability? {
        profiles.first { $0.dataFormat == container.defaultDataFormat }
    }
}

public struct AudioDevice: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public init(id: String, name: String) { self.id = id; self.name = name }
}

public struct SpeechCapabilities: Sendable {
    public var outputs: [OutputCapability]
    public var devices: [AudioDevice]
    public var supportsNetworkAudio: Bool
    public var speedRange: ClosedRange<Int>
    public init(outputs: [OutputCapability] = [], devices: [AudioDevice] = [], supportsNetworkAudio: Bool = false, speedRange: ClosedRange<Int> = 80...500) {
        self.outputs = outputs; self.devices = devices; self.supportsNetworkAudio = supportsNetworkAudio; self.speedRange = speedRange
    }
}

public struct SpeechRequest: Sendable {
    public let text: String
    public let settings: SpeechSettings
    public let destination: URL?
    public let output: ExportSettings
    public init(text: String, settings: SpeechSettings, destination: URL? = nil, output: ExportSettings = .init()) {
        self.text = text; self.settings = settings; self.destination = destination; self.output = output
    }
}

public enum SpeechError: LocalizedError, Equatable {
    case invalidSettings(String)
    case processFailed(String)
    case nativeOutputUnavailable(String)
    case captureUnavailable(String)
    case captureFailed(String)
    case emptyAudio
    case busy
    public var errorDescription: String? {
        switch self {
        case .invalidSettings(let message), .processFailed(let message): return message
        case .nativeOutputUnavailable(let message): return "Personal Voice native output is unavailable: \(message)"
        case .captureUnavailable(let message): return "Personal Voice Export is unavailable: \(message)"
        case .captureFailed(let message): return "Personal Voice audio capture failed: \(message)"
        case .emptyAudio: return "The system did not produce any audio."
        case .busy: return "A speech job is already running."
        }
    }
}

/// The sole substitutable speech system boundary. All synthesis remains system `say`.
@MainActor public protocol SpeechSystem: AnyObject {
    func voices() async throws -> [Voice]
    func capabilities() async throws -> SpeechCapabilities
    func authorization() -> PersonalVoiceAuthorization
    func requestAuthorization() async -> PersonalVoiceAuthorization
    func speak(_ request: SpeechRequest) async throws
    func capturePersonalVoice(_ request: SpeechRequest) async throws
    func stop()
}
