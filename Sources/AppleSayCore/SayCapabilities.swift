import AudioToolbox
import Foundation

enum SayCatalog {
    static func voices(from listing: String) -> [Voice] {
        // Voice names may contain spaces and parentheses; locale is the column
        // immediately before the sample-text marker, not a fixed character offset.
        guard let expression = try? NSRegularExpression(pattern: #"^(.+?)\s+([A-Za-z]{2,3}[_-][A-Za-z0-9_-]+)\s*#"#) else {
            return []
        }
        return listing.split(whereSeparator: \.isNewline).compactMap { line in
            let value = String(line)
            guard let match = expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
                  let nameRange = Range(match.range(at: 1), in: value),
                  let languageRange = Range(match.range(at: 2), in: value) else { return nil }
            let name = String(value[nameRange]).trimmingCharacters(in: .whitespaces)
            let language = String(value[languageRange])
            return Voice(id: name, name: name, language: language)
        }
    }

    static func identifiers(from listing: String) -> [String] {
        listing.split(whereSeparator: \.isNewline).compactMap { $0.split(whereSeparator: \.isWhitespace).first.map(String.init) }
    }

    static func devices(from listing: String) -> [AudioDevice] {
        listing.split(whereSeparator: \.isNewline).compactMap { line in
            let columns = line.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            guard columns.count == 2, UInt32(columns[0]) != nil else { return nil }
            return AudioDevice(id: String(columns[0]), name: String(columns[1]).trimmingCharacters(in: .whitespaces))
        }
    }
}

@MainActor enum SayCapabilityDiscovery {
    static func discover(using runner: SayProcess) async throws -> SpeechCapabilities {
        let formats = try await runner.run(arguments: ["--file-format=?"]).checked()
        let supported = Set(SayCatalog.identifiers(from: formats))
        var aacBitRates: [Int] = []
        if supported.contains("m4af") || supported.contains("caff") {
            let rates = try await runner.run(arguments: ["--file-format=m4af", "--data-format=aac", "--bit-rate=?"])
            if rates.status == 0 {
                aacBitRates = SayCatalog.identifiers(from: rates.standardOutput).compactMap(Int.init)
            }
        }
        var outputs: [OutputCapability] = []
        for container in AudioContainer.allCases where supported.contains(container.sayFormat) {
            if let output = try await discoverOutput(container, aacBitRates: aacBitRates, runner: runner) {
                outputs.append(output)
            }
        }
        let devices = try await runner.run(arguments: ["--audio-device=?"]).checked()
        var component = AudioComponentDescription(componentType: kAudioUnitType_Effect,
                                                  componentSubType: kAudioUnitSubType_NetSend,
                                                  componentManufacturer: kAudioUnitManufacturer_Apple,
                                                  componentFlags: 0, componentFlagsMask: 0)
        let hasNetworkAudio = AudioComponentFindNext(nil, &component) != nil
        return SpeechCapabilities(outputs: outputs, devices: SayCatalog.devices(from: devices),
                                  supportsNetworkAudio: hasNetworkAudio)
    }

    private static func discoverOutput(_ container: AudioContainer, aacBitRates: [Int],
                                       runner: SayProcess) async throws -> OutputCapability? {
        let listing = try await runner.run(arguments: ["--file-format=\(container.sayFormat)", "--data-format=?"]).checked()
        let listedFormats = SayCatalog.identifiers(from: listing).flatMap { identifier -> [String] in
            if identifier == "lpcm" { return pcmCandidates(for: container) }
            return usefulCompressedFormats(for: container).contains(identifier) ? [identifier] : []
        }
        let profiles = Set(listedFormats).map { format in
            discoverProfile(format, container: container, aacBitRates: aacBitRates)
        }.sorted { left, right in
            if left.dataFormat == container.defaultDataFormat { return true }
            if right.dataFormat == container.defaultDataFormat { return false }
            return left.dataFormat < right.dataFormat
        }
        return profiles.isEmpty ? nil : OutputCapability(container: container, profiles: profiles)
    }

    private static func discoverProfile(_ format: String, container: AudioContainer,
                                        aacBitRates: [Int]) -> AudioDataCapability {
        let channels = [1, 2]
        let bitRates = (format == "aac") ? aacBitRates : []
        let supportsQuality = (format == "aac")
        return AudioDataCapability(dataFormat: format, channels: channels, bitRates: bitRates,
                                   supportsQuality: supportsQuality)
    }

    private static func pcmCandidates(for container: AudioContainer) -> [String] {
        switch container {
        case .aiff: return ["BEI16", "BEI24", "BEI32"]
        case .wav: return ["LEI16", "LEI24", "LEI32", "LEF32"]
        case .caf: return ["LEI16", "LEI24", "LEI32", "LEF32"]
        case .m4a: return ["LEI16", "LEI24"]
        }
    }

    private static func usefulCompressedFormats(for container: AudioContainer) -> Set<String> {
        switch container {
        case .aiff, .wav: []
        case .caf: ["aac", "alac", "flac"]
        case .m4a: ["aac", "alac"]
        }
    }
}

enum SayArguments {
    static func make(for request: SpeechRequest, input: URL) throws -> [String] {
        guard request.settings.speed > 0 else { throw SpeechError.invalidSettings("Speech Speed must be positive.") }
        var arguments = ["-r", String(request.settings.speed), "-f", input.path]
        if let voice = request.settings.voice { arguments += ["-v", voice.name] }
        if let destination = request.destination {
            guard request.settings.outputDevice == nil, request.settings.networkService == nil else {
                throw SpeechError.invalidSettings("Output devices and network audio apply to Preview only.")
            }
            arguments += ["-o", destination.path, "--file-format=\(request.output.container.sayFormat)"]
            arguments += ["--data-format=\(request.output.dataFormat ?? request.output.container.defaultDataFormat)"]
            if let count = request.output.channels { arguments += ["--channels=\(count)"] }
            if let rate = request.output.bitRate { arguments += ["--bit-rate=\(rate)"] }
            if let quality = request.output.quality { arguments += ["--quality=\(quality)"] }
        } else {
            guard request.settings.outputDevice == nil || request.settings.networkService == nil else {
                throw SpeechError.invalidSettings("Choose either an output device or network audio.")
            }
            if let device = request.settings.outputDevice { arguments += ["-a", device] }
            if let service = request.settings.networkService { arguments += ["-n", service] }
        }
        return arguments
    }

    static func inputText(for request: SpeechRequest) throws -> String {
        guard let pitch = request.settings.pitch else { return request.text }
        guard pitch.isFinite, (1...1000).contains(pitch) else {
            throw SpeechError.invalidSettings("Pitch must be between 1 and 1,000 Hz.")
        }
        return "[[pbas \(pitch)]]" + request.text
    }
}
