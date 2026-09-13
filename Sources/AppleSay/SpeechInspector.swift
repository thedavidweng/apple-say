import SwiftUI
import AppleSayCore

struct SpeechInspector: View {
    let speech: SpeechController
    @Binding var settings: SpeechSettings
    @Binding var output: ExportSettings
    @Binding var language: String
    let strings: AppStrings
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
            Section(strings.text("Speech", "语音")) {
                Picker(strings.text("Voice Language", "声音语言"), selection: $language) {
                    Text(strings.text("All Languages", "所有语言")).tag("")
                    ForEach(languages, id: \.self) { locale in
                        Text(strings.locale.localizedString(forIdentifier: locale) ?? locale).tag(locale)
                    }
                }
                .help(strings.text("Filters the Voice list. Document text stays unchanged.", "筛选声音列表，不会更改文稿文本。"))
                LabeledContent(strings.text("Voice", "声音")) {
                    VoicePopUp(voices: visibleVoices, selection: $settings.voice, strings: strings)
                        .frame(minWidth: 130)
                }
                LabeledContent(strings.text("Speech Speed", "语速")) {
                    Text(strings.text("\(settings.speed) words/min", "每分钟 \(settings.speed) 字")).monospacedDigit()
                }
                Slider(value: Binding(
                    get: { Double(settings.speed) }, set: { settings.speed = Int($0.rounded()) }
                ), in: Double(speech.capabilities.speedRange.lowerBound)...Double(speech.capabilities.speedRange.upperBound))
                .accessibilityLabel(strings.text("Speech Speed", "语速"))
                .accessibilityValue(strings.text("\(settings.speed) words per minute", "每分钟 \(settings.speed) 字"))
                Toggle(strings.text("Natural Pitch", "自然音高"), isOn: Binding(
                    get: { settings.pitch == nil }, set: { settings.pitch = $0 ? nil : 50 }
                ))
                if settings.pitch != nil {
                    TextField(strings.text("Pitch (Hz)", "音高（Hz）"), value: Binding(
                        get: { settings.pitch ?? 50 }, set: { settings.pitch = $0 }
                    ), format: .number)
                    .accessibilityLabel(strings.text("Pitch in hertz", "音高赫兹数"))
                }
                Button(strings.text("Reset Speed and Pitch", "重置语速和音高")) {
                    settings.speed = SpeechSettings().speed
                    settings.pitch = nil
                }
            }

            Section(strings.text("Personal Voice", "个人声音")) {
                personalVoiceStatus
            }

            Section(strings.text("Export", "导出")) {
                if speech.capabilities.outputs.isEmpty {
                    Text(strings.text("No supported audio formats are available.", "没有可用的受支持音频格式。"))
                        .foregroundStyle(.secondary)
                } else {
                    Picker(strings.text("Audio Format", "音频格式"), selection: $output.container) {
                        ForEach(speech.capabilities.outputs, id: \.container) { capability in
                            Text(capability.container.title).tag(capability.container)
                        }
                    }
                    .onChange(of: output.container) { _, container in
                        output = ExportSettings(container: container)
                    }
                }
                DisclosureGroup(strings.text("Advanced", "高级")) {
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
            Text(strings.text("Allow Apple Say to use your Personal Voices.", "允许 Apple Say 使用你的个人声音。"))
                .foregroundStyle(.secondary)
            Button(strings.text("Authorize Personal Voice…", "授权个人声音…"), action: authorize)
        case .authorized:
            Text(strings.text(
                "Authorized. Available Personal Voices appear in the Voice menu.",
                "已授权。可用的个人声音会显示在声音菜单中。"
            ))
                .foregroundStyle(.secondary)
        case .denied:
            Text(strings.text(
                "Access was denied. Allow Apple Say in Personal Voice Settings.",
                "访问被拒绝。请在个人声音设置中允许 Apple Say 访问。"
            ))
                .foregroundStyle(.secondary)
            Button(strings.text("Personal Voice Settings…", "个人声音设置…")) { VoiceManagement.open(.personalVoice) }
        case .restricted:
            Text(strings.text("Personal Voice access is restricted by this Mac.", "此 Mac 限制了个人声音访问。"))
                .foregroundStyle(.secondary)
        case .unsupported:
            Text(strings.text("Personal Voice is unavailable on this Mac.", "此 Mac 不支持个人声音。"))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var advancedOutput: some View {
        if let capability {
            if !capability.profiles.isEmpty {
                Picker(strings.text("Data Format", "数据格式"), selection: $output.dataFormat) {
                    Text(strings.text("Automatic", "自动")).tag(String?.none)
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
                Picker(strings.text("Channels", "声道"), selection: $output.channels) {
                    Text(strings.text("Automatic", "自动")).tag(Int?.none)
                    ForEach(profile.channels, id: \.self) { channels in
                        Text(channels == 1 ? strings.text("Mono", "单声道")
                            : channels == 2 ? strings.text("Stereo", "立体声") : "\(channels)")
                            .tag(Optional(channels))
                    }
                }
            }
            if let profile, !profile.bitRates.isEmpty {
                Picker(strings.text("Bitrate", "比特率"), selection: $output.bitRate) {
                    Text(strings.text("Automatic", "自动")).tag(Int?.none)
                    ForEach(profile.bitRates, id: \.self) { rate in
                        Text("\(rate / 1000) kbps").tag(Optional(rate))
                    }
                }
            }
            if profile?.supportsQuality == true {
                Picker(strings.text("Converter Quality", "转换质量"), selection: $output.quality) {
                    Text(strings.text("Automatic", "自动")).tag(Int?.none)
                    Text(strings.text("Minimum", "最低")).tag(Optional(0))
                    Text(strings.text("Low", "低")).tag(Optional(32))
                    Text(strings.text("Medium", "中")).tag(Optional(64))
                    Text(strings.text("High", "高")).tag(Optional(96))
                    Text(strings.text("Maximum", "最高")).tag(Optional(127))
                }
            }
        }
    }

    @ViewBuilder private var advancedPlayback: some View {
        if !speech.capabilities.devices.isEmpty {
            Picker(strings.text("Output Device", "输出设备"), selection: $settings.outputDevice) {
                Text(strings.text("System Default", "系统默认")).tag(String?.none)
                ForEach(speech.capabilities.devices) { device in
                    Text(device.name).tag(Optional(device.id))
                }
            }
        }
        if speech.capabilities.supportsNetworkAudio {
            TextField(strings.text("Network Audio Service", "网络音频服务"), text: Binding(
                get: { settings.networkService ?? "" },
                set: { settings.networkService = $0.isEmpty ? nil : $0 }
            ))
            .help(strings.text(
                "The name of an available system network audio service.",
                "可用系统网络音频服务的名称。"
            ))
        }
    }
}
