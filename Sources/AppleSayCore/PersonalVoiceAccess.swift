import AVFAudio
import Foundation

/// AVFAudio is used only for Apple's permission and voice metadata APIs, never synthesis.
@MainActor public final class PersonalVoiceAccess {
    public init() {}

    public func authorization() -> PersonalVoiceAuthorization {
        Self.map(AVSpeechSynthesizer.personalVoiceAuthorizationStatus)
    }

    public func requestAuthorization() async -> PersonalVoiceAuthorization {
        await withCheckedContinuation { continuation in
            AVSpeechSynthesizer.requestPersonalVoiceAuthorization { status in
                continuation.resume(returning: Self.map(status))
            }
        }
    }

    private nonisolated static func map(_ status: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus) -> PersonalVoiceAuthorization {
        switch status {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .unsupported: return .unsupported
        case .authorized: return .authorized
        // Apple's public API has no separate restricted state. Unknown future states deny access.
        @unknown default: return .restricted
        }
    }
}
