import Foundation

extension SpeechCapabilities {
    func validate(_ speech: SpeechSettings, output: ExportSettings?, timed: Bool) throws {
        guard speedRange.contains(speech.speed) else { throw SpeechError.invalidSettings("Speech Speed is outside the supported range.") }
        if let pitch = speech.pitch, !pitch.isFinite || !(1...1000).contains(pitch) {
            throw SpeechError.invalidSettings("Pitch must be between 1 and 1,000 Hz.")
        }
        if let device = speech.outputDevice, !devices.contains(where: { $0.id == device }) {
            throw SpeechError.invalidSettings("The selected audio output device is no longer available.")
        }
        if let service = speech.networkService {
            guard supportsNetworkAudio, !service.trimmingCharacters(in: .whitespaces).isEmpty,
                  speech.outputDevice == nil, !timed, output == nil else {
                throw SpeechError.invalidSettings("Network audio is available for Plain Text Preview with the default output device.")
            }
        }
        guard let output else { return }
        guard let capability = outputs.first(where: { $0.container == output.container }) else {
            throw SpeechError.invalidSettings("This audio container is not available on this Mac.")
        }
        let format = output.dataFormat ?? output.container.defaultDataFormat
        guard let profile = capability.profiles.first(where: { $0.dataFormat == format }) else {
            throw SpeechError.invalidSettings("This data format is not supported by the selected container.")
        }
        if let channels = output.channels, !profile.channels.contains(channels) {
            throw SpeechError.invalidSettings("This channel layout is not supported by the selected container.")
        }
        if let bitRate = output.bitRate {
            guard profile.bitRates.contains(bitRate) else {
                throw SpeechError.invalidSettings("This bitrate is not supported by the selected data format.")
            }
        }
        if let quality = output.quality {
            guard profile.supportsQuality, (0...127).contains(quality) else {
                throw SpeechError.invalidSettings("Converter quality requires a supported compressed data format.")
            }
        }
    }
}

public struct TimingError: LocalizedError, Equatable {
    public let line: Int
    public let fragment: Int?
    public let start: Double
    public let deadline: Double?
    public var errorDescription: String? {
        let location = fragment.map { "line \(line), Timed Fragment \($0)" } ?? "line \(line)"
        if let deadline {
            return "Timing Error on \(location): speech starting at \(start.formatted()) s cannot fit before \(deadline.formatted()) s. Adjust the text or Timestamps."
        }
        return "Timing Error on \(location): the Timestamp must be at or after zero."
    }
}
