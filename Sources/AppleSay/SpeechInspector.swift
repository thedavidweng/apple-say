import SwiftUI
import AppleSayCore

struct SpeechInspector: View {
    let speech: SpeechController
    @Binding var settings: SpeechSettings
    @Binding var output: ExportSettings
    @Binding var language: String
    let authorize: () -> Void

    private var languages: [String] { Array(Set(speech.voices.map(\.language))).sorted() }
    private var visibleVoices: [Voice] { speech.voices.filter { language.isEmpty || $0.language == language } }
    private var capability: OutputCapability? { speech.capabilities.outputs.first { $0.container == output.container } }
    private var profile: AudioDataCapability? {
        let format = output.dataFormat ?? output.container.defaultDataFormat
        return capability?.profiles.first { $0.dataFormat == format }
    }

    var body: some View {
        Form {
            Section("Speech") {
                Picker("Voice Language", selection: $language) {
                    Text("All Languages").tag("")
                    ForEach(languages, id: \.self) { locale in
                        Text(Locale.current.localizedString(forIdentifier: locale) ?? locale).tag(locale)
                    }
                }
                .help("Filters the Voice list. Document text stays unchanged.")
                LabeledContent("Voice") {
                    VoicePopUp(voices: visibleVoices, selection: $settings.voice)
                        .frame(minWidth: 130)
                }
                LabeledContent("Speech Speed") {
                    Text("\(settings.speed) words/min").monospacedDigit()
                }
                Slider(value: Binding(
                    get: { Double(settings.speed) }, set: { settings.speed = Int($0) }
                ), in: Double(speech.capabilities.speedRange.lowerBound)...Double(speech.capabilities.speedRange.upperBound), step: 1)
                .accessibilityLabel("Speech Speed")
                .accessibilityValue("\(settings.speed) words per minute")
                Toggle("Natural Pitch", isOn: Binding(
                    get: { settings.pitch == nil }, set: { settings.pitch = $0 ? nil : 50 }
                ))
                if settings.pitch != nil {
                    TextField("Pitch (Hz)", value: Binding(
                        get: { settings.pitch ?? 50 }, set: { settings.pitch = $0 }
                    ), format: .number)
                    .accessibilityLabel("Pitch in hertz")
                }
                Button("Reset Speed and Pitch") {
                    settings.speed = SpeechSettings().speed
                    settings.pitch = nil
                }
            }

            Section("Personal Voice") {
                personalVoiceStatus
            }

            Section("Export") {
                if speech.capabilities.outputs.isEmpty {
                    Text("No supported audio formats are available.").foregroundStyle(.secondary)
                } else {
                    Picker("Audio Format", selection: $output.container) {
                        ForEach(speech.capabilities.outputs, id: \.container) { capability in
                            Text(capability.container.title).tag(capability.container)
                        }
                    }
                    .onChange(of: output.container) { _, container in
                        output = ExportSettings(container: container)
                    }
                }
                DisclosureGroup("Advanced") {
                    advancedOutput
                    advancedPlayback
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder private var personalVoiceStatus: some View {
        switch speech.authorization {
        case .notDetermined:
            Text("Allow Apple Say to use your Personal Voices.").foregroundStyle(.secondary)
            Button("Authorize Personal Voice…", action: authorize)
        case .authorized:
            Text("Authorized. Available Personal Voices appear in the Voice menu.")
                .foregroundStyle(.secondary)
        case .denied:
            Text("Access was denied. Allow Apple Say in Personal Voice Settings.")
                .foregroundStyle(.secondary)
            Button("Personal Voice Settings…") { VoiceManagement.open(.personalVoice) }
        case .restricted:
            Text("Personal Voice access is restricted by this Mac.").foregroundStyle(.secondary)
        case .unsupported:
            Text("Personal Voice is unavailable on this Mac.").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var advancedOutput: some View {
        if let capability {
            if !capability.profiles.isEmpty {
                Picker("Data Format", selection: $output.dataFormat) {
                    Text("Automatic").tag(String?.none)
                    ForEach(capability.profiles, id: \.dataFormat) { profile in
                        Text(profile.dataFormat).tag(Optional(profile.dataFormat))
                    }
                }
                .onChange(of: output.dataFormat) { _, _ in
                    output.channels = nil
                    output.bitRate = nil
                    output.quality = nil
                }
            }
            if let profile, !profile.channels.isEmpty {
                Picker("Channels", selection: $output.channels) {
                    Text("Automatic").tag(Int?.none)
                    ForEach(profile.channels, id: \.self) { channels in
                        Text(channels == 1 ? "Mono" : channels == 2 ? "Stereo" : "\(channels)").tag(Optional(channels))
                    }
                }
            }
            if let profile, !profile.bitRates.isEmpty {
                Picker("Bitrate", selection: $output.bitRate) {
                    Text("Automatic").tag(Int?.none)
                    ForEach(profile.bitRates, id: \.self) { rate in
                        Text("\(rate / 1000) kbps").tag(Optional(rate))
                    }
                }
            }
            if profile?.supportsQuality == true {
                Picker("Converter Quality", selection: $output.quality) {
                    Text("Automatic").tag(Int?.none)
                    Text("Minimum").tag(Optional(0))
                    Text("Low").tag(Optional(32))
                    Text("Medium").tag(Optional(64))
                    Text("High").tag(Optional(96))
                    Text("Maximum").tag(Optional(127))
                }
            }
        }
    }

    @ViewBuilder private var advancedPlayback: some View {
        if !speech.capabilities.devices.isEmpty {
            Picker("Output Device", selection: $settings.outputDevice) {
                Text("System Default").tag(String?.none)
                ForEach(speech.capabilities.devices) { device in
                    Text(device.name).tag(Optional(device.id))
                }
            }
        }
        if speech.capabilities.supportsNetworkAudio {
            TextField("Network Audio Service", text: Binding(
                get: { settings.networkService ?? "" },
                set: { settings.networkService = $0.isEmpty ? nil : $0 }
            ))
            .help("The name of an available system network audio service.")
        }
    }
}
