import SwiftUI
import AppleSayCore

struct SpeechInspector: View {
    let speech: SpeechController
    @Binding var settings: SpeechSettings
    @Binding var output: ExportSettings
    @Binding var language: String
    let strings: AppStrings
    let authorize: () -> Void
    @State private var showVoiceQualityInfo = false

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
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .help(strings.text(
                    "Choose a Voice, or choose “Add Voices…” from the menu to install higher quality voices.",
                    "选择声音，或从菜单中选择“添加声音…”安装更高品质的声音。"
                ))
                HStack(spacing: 8) {
                    Text(strings.text("Voice Quality", "声音品质"))
                    Spacer()
                    let display = currentVoiceQualityDisplay
                    HStack(spacing: 6) {
                        Circle()
                            .fill(display.color)
                            .frame(width: 7, height: 7)
                        Text(display.title)
                            .foregroundStyle(.primary)
                            .fontWeight(.medium)
                    }
                    .accessibilityElement(children: .combine)
                    Button {
                        showVoiceQualityInfo.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(strings.text("Voice Quality Guide", "声音品质说明"))
                    .help(strings.text("Voice Quality Guide", "声音品质说明"))
                    .popover(isPresented: $showVoiceQualityInfo, arrowEdge: .trailing) {
                        VoiceQualityHelpView(strings: strings)
                    }
                }
                .accessibilityElement(children: .contain)
                if let voice = settings.voice {
                    if voice.quality < .enhanced && !voice.isPersonal {
                        Text(strings.text(
                            "Default system voices sound mechanical. Choose “Add Voices…” from the Voice menu to install Enhanced or Premium voices.",
                            "系统默认声音偏机械。可从“声音”菜单中选择“添加声音…”，在系统设置中安装增强或高级声音。"
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } else {
                    let info = systemVoiceInfo
                    if info?.isSiri != true {
                        Text(strings.text(
                            "Default system voices sound mechanical. Choose “Add Voices…” from the Voice menu to install Enhanced or Premium voices.",
                            "系统默认声音偏机械。可从“声音”菜单中选择“添加声音…”，在系统设置中安装增强或高级声音。"
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                LabeledContent(strings.text("Speech Speed", "语速")) {
                    HStack(spacing: 6) {
                        Text(strings.text("\(settings.speed) words/min", "每分钟 \(settings.speed) 字")).monospacedDigit()
                        if settings.speed != SpeechSettings().speed {
                            Button {
                                settings.speed = SpeechSettings().speed
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .imageScale(.small)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .help(strings.text(
                                "Reset Speech Speed to default (\(SpeechSettings().speed) words/min)",
                                "还原语速为默认值（每分钟 \(SpeechSettings().speed) 字）"
                            ))
                        }
                    }
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
            Text(strings.text(
                "Use your Personal Voice for Preview and Export. macOS will ask for your permission.",
                "使用个人声音进行播放和导出。macOS 会先征求你的许可。"
            ))
                .foregroundStyle(.secondary)
            Button(strings.text("Continue…", "继续…"), action: authorize)
        case .authorized:
            authorizedPersonalVoiceStatus
        case .denied:
            Text(strings.text(
                "Allow applications to request Personal Voice access, then allow Apple Say in System Settings.",
                "请允许应用程序请求个人声音访问，然后在系统设置中允许 Apple Say。"
            ))
                .foregroundStyle(.secondary)
            Button(strings.text("Open Personal Voice Settings…", "打开个人声音设置…")) {
                VoiceManagement.open(.personalVoice)
            }
        case .restricted:
            Text(strings.text("Personal Voice access is restricted by this Mac.", "此 Mac 限制了个人声音访问。"))
                .foregroundStyle(.secondary)
        case .unsupported:
            Text(strings.text("Personal Voice is unavailable on this Mac.", "此 Mac 不支持个人声音。"))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var authorizedPersonalVoiceStatus: some View {
        switch speech.personalVoiceCapability {
        case .unavailable:
            Text(strings.text("No Personal Voices are installed.", "尚未安装个人声音。"))
                .foregroundStyle(.secondary)
            Button(strings.text("Personal Voice Settings…", "个人声音设置…")) { VoiceManagement.open(.personalVoice) }
        case .playbackOnly:
            Text(strings.text("✓ Playback available", "✓ 可以播放"))
            Text(strings.text("— File export is unavailable on this macOS version", "— 此 macOS 版本无法导出文件"))
                .foregroundStyle(.secondary)
            Button(strings.text("Personal Voice Settings…", "个人声音设置…")) { VoiceManagement.open(.personalVoice) }
        case .nativeExport, .compatibilityExport:
            Text(strings.text("Playback and file export are available.", "可以播放和导出文件。"))
                .foregroundStyle(.secondary)
        case .ready:
            Text(strings.text(
                "Authorized. File export support will be checked when first used.",
                "已授权。首次导出时会检查文件导出能力。"
            ))
            .foregroundStyle(.secondary)
        case .permissionRequired, .unsupported:
            EmptyView()
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

    private func qualityLabel(for voice: Voice) -> String {
        if voice.isPersonal {
            return strings.text("Personal Voice", "个人声音")
        }
        if voice.isNovelty {
            return strings.text("Novelty", "趣味声音")
        }
        return strings.qualityName(voice.quality)
    }

    private var currentVoiceQualityDisplay: (title: String, color: Color) {
        if let voice = settings.voice {
            let label = qualityLabel(for: voice)
            let color = VoiceQualityTheme.color(
                for: voice.quality,
                isPersonal: voice.isPersonal,
                isNovelty: voice.isNovelty
            )
            return (label, color)
        } else {
            if let info = systemVoiceInfo, info.isSiri {
                return (strings.text("Siri Natural", "Siri 自然声音"), VoiceQualityTheme.siri)
            } else {
                return (strings.text("System Configured", "系统设定"), VoiceQualityTheme.compact)
            }
        }
    }

    private var systemVoiceInfo: SystemVoiceInfo? {
        SystemSpeech.currentSystemVoice(
            preferredLanguages: language.isEmpty ? Locale.preferredLanguages : [language]
        )
    }
}

enum VoiceQualityTheme {
    static let siri = Color.accentColor
    static let premium = Color.accentColor
    static let enhanced = Color.accentColor
    static let compact = Color.secondary
    static let legacy = Color.secondary
    static let novelty = Color.orange
    static let personal = Color.accentColor

    static func color(for quality: VoiceQuality, isPersonal: Bool = false, isNovelty: Bool = false) -> Color {
        if isPersonal { return personal }
        if isNovelty { return novelty }
        switch quality {
        case .premium: return premium
        case .enhanced: return enhanced
        case .compact: return compact
        case .legacy, .standard: return legacy
        }
    }
}

struct VoiceQualityHelpView: View {
    let strings: AppStrings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(strings.text("Voice Qualities", "声音品质说明"))
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                qualityRow(
                    name: strings.text("Siri Voice", "Siri 声音"),
                    badge: strings.text("Most Natural", "最自然"),
                    badgeColor: VoiceQualityTheme.siri,
                    description: strings.text(
                        "Apple's most natural neural voice. In macOS, it cannot be called directly by name, "
                            + "but can be used by choosing “System Voice” when configured in macOS Accessibility settings.",
                        "苹果最自然的神经网络拟真语音。在 macOS 中无法通过名称直接指定，"
                            + "但只要在系统设置的辅助功能中设为系统声音，并在本软件中选择“系统声音”，即可直接使用并支持导出。"
                    )
                )

                Divider()

                qualityRow(
                    name: strings.text("Premium", "高级"),
                    badge: strings.text("High Fidelity", "高保真"),
                    badgeColor: VoiceQualityTheme.premium,
                    description: strings.text(
                        "High-definition, highly expressive natural voice (~500MB+). Requires downloading in macOS Accessibility settings.",
                        "细节丰富、拟真度与表现力极高的高保真声音（体积通常 500MB 以上）。可在 macOS 辅助功能设置中下载。"
                    )
                )

                Divider()

                qualityRow(
                    name: strings.text("Enhanced", "增强"),
                    badge: strings.text("Natural", "自然"),
                    badgeColor: VoiceQualityTheme.enhanced,
                    description: strings.text(
                        "Smooth synthesis with natural intonation (~200MB). Requires downloading in macOS Accessibility settings.",
                        "语调平滑自然、发音连贯的增强合成声音（体积约 200MB）。可在 macOS 辅助功能设置中下载。"
                    )
                )

                Divider()

                qualityRow(
                    name: strings.text("Compact", "精简"),
                    badge: strings.text("Standard", "标准"),
                    badgeColor: VoiceQualityTheme.compact,
                    description: strings.text(
                        "Lightweight voice pre-installed with macOS (~15MB). Fast and resource-friendly, but sounds somewhat mechanical.",
                        "macOS 默认预装的轻量级声音（体积约 15MB）。体积小、响应快，但声音偏机械感。"
                    )
                )

                Divider()

                qualityRow(
                    name: strings.text("Legacy", "经典"),
                    badge: strings.text("Compatibility", "兼容"),
                    badgeColor: VoiceQualityTheme.legacy,
                    description: strings.text(
                        "Classic macOS synthesizer voices retained for historical compatibility.",
                        "早期 Mac 系统保留的经典合成声音，主要用于向后兼容历史系统。"
                    )
                )

                Divider()

                qualityRow(
                    name: strings.text("Novelty", "趣味声音"),
                    badge: strings.text("Special Effects", "特殊音效"),
                    badgeColor: VoiceQualityTheme.novelty,
                    description: strings.text(
                        "Sound-effect voices (such as Bells, Cellos, Bubbles, Zarvox) for creative or playful scenarios.",
                        "特殊音效与趣味声音（如 Bells、Cellos、Bubbles、Zarvox 等），适合特殊创意或趣味场景。"
                    )
                )
            }

            HStack {
                Spacer()
                Button(strings.text("Open Accessibility Settings…", "打开辅助功能设置…")) {
                    VoiceManagement.open(.voices)
                }
                .buttonStyle(.link)
                .font(.footnote)
            }
        }
        .padding(16)
        .frame(width: 380, alignment: .leading)
    }

    private func qualityRow(name: String, badge: String, badgeColor: Color, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(badgeColor)
                    .frame(width: 8, height: 8)
                Text(name)
                    .font(.subheadline.bold())
                Spacer()
                Text(badge)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
