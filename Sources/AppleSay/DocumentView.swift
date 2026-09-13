import AppKit
import AVFAudio
import SwiftUI
import UniformTypeIdentifiers
import AppleSayCore

struct DocumentView: View {
    @Binding var document: SayDocument
    let fileURL: URL?
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppLanguagePreference.defaultsKey) private var languagePreference = AppLanguagePreference.system.rawValue
    @AppStorage("hasShownWelcomeDocument") private var hasShownWelcomeDocument = false
    @State private var speech = SpeechController(system: SystemSpeech())
    @State private var settings = SpeechSettings()
    @State private var output = ExportSettings()
    @State private var inspectorPresented = true
    @State private var language = ""
    @State private var hasInitializedLanguage = false
    @State private var errorMessage: String?
    @State private var showPersonalVoiceSettingsGuidance = false
    @State private var refreshing = false

    private var strings: AppStrings { AppStrings(preferenceRawValue: languagePreference) }
    private var appLanguagePreference: AppLanguagePreference {
        AppLanguagePreference(rawValue: languagePreference) ?? .system
    }
    private var busy: Bool { speech.state.isActive }

    private var hasText: Bool { !document.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var selectedVoiceAvailable: Bool {
        settings.voice.map { selected in speech.voices.contains { $0.id == selected.id } } ?? true
    }
    private var canPreview: Bool { hasText && !busy && !refreshing && selectedVoiceAvailable }
    private var canExport: Bool { canPreview && !speech.capabilities.outputs.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $document.text)
                .font(.system(size: 16))
                .padding(18)
                .accessibilityLabel(strings.text("Document text", "文稿文本"))
                .accessibilityHint(strings.text(
                    "Enter Plain Text, LRC, or Enhanced LRC to speak.",
                    "输入纯文本、LRC 或增强型 LRC 后即可播放。"
                ))
            Divider()
            statusBar
        }
        .frame(minWidth: 480, minHeight: 360)
        .inspector(isPresented: $inspectorPresented) {
            SpeechInspector(
                speech: speech, settings: $settings, output: $output, language: $language,
                strings: strings, authorize: authorize
            )
            .inspectorColumnWidth(min: 270, ideal: 300, max: 360)
            .disabled(busy || refreshing)
        }
        .toolbar {
            ToolbarItemGroup {
                Button(action: preview) { Label(strings.text("Preview", "播放"), systemImage: "play.fill") }
                    .disabled(!canPreview)
                    .help(strings.text("Preview (⌘Return)", "播放（⌘Return）"))
                Button(action: speech.stop) { Label(strings.text("Stop", "停止"), systemImage: "stop.fill") }
                    .disabled(!busy)
                    .help(strings.text("Stop (⌘.)", "停止（⌘.）"))
                Button(action: export) { Label(strings.text("Export", "导出"), systemImage: "square.and.arrow.up") }
                    .disabled(!canExport)
                    .help(strings.text("Export Audio (⇧⌘E)", "导出音频（⇧⌘E）"))
            }
            ToolbarItem(placement: .automatic) {
                Button { inspectorPresented.toggle() } label: {
                    Label(strings.text("Speech Inspector", "语音检查器"), systemImage: "sidebar.right")
                }
                .help(strings.text("Show or hide Speech Inspector (⌥⌘I)", "显示或隐藏语音检查器（⌥⌘I）"))
            }
        }
        .focusedSceneValue(\.speechActions, SpeechActions(
            preview: preview, stop: speech.stop, export: export,
            toggleInspector: { inspectorPresented.toggle() },
            canPreview: canPreview, canStop: busy, canExport: canExport
        ))
        .task {
            prepareWelcomeDocument()
            await refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refresh() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVSpeechSynthesizer.availableVoicesDidChangeNotification)) { _ in
            Task { await refresh() }
        }
        .onDisappear { speech.stop() }
        .alert("Apple Say", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button(strings.text("OK", "好"), role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .alert(strings.text("Allow Personal Voice", "允许个人声音"),
               isPresented: $showPersonalVoiceSettingsGuidance) {
            Button(strings.text("Cancel", "取消"), role: .cancel) {}
            Button(strings.text("Open System Settings", "打开系统设置")) {
                VoiceManagement.open(.personalVoice)
            }
        } message: {
            Text(strings.text(
                "Turn on “Allow applications to request to use Personal Voice,” then allow Apple Say in the app list.",
                "请开启“允许应用程序请求使用个人声音”，然后在应用列表中允许 Apple Say。"
            ))
        }
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            Text(formatLabel)
                .help(strings.text(
                    "Document format is detected automatically from its complete contents.",
                    "Apple Say 会根据文稿的完整内容自动识别格式。"
                ))
            Spacer()
            if busy || refreshing { ProgressView().controlSize(.small) }
            Text(refreshing ? strings.text("Loading Voices…", "正在载入声音…") : statusLabel)
                .lineLimit(1)
                .help(statusLabel)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }

    private var formatLabel: String {
        let parsed = SpeechController.analyze(document.text)
        switch parsed.format {
        case .plainText: return strings.text("Plain Text", "纯文本")
        case .lrc:
            return strings.text("LRC · \(parsed.segments.count) Segments", "LRC · \(parsed.segments.count) 段")
        case .enhancedLRC:
            return strings.text("Enhanced LRC · \(parsed.segments.count) Segments", "增强型 LRC · \(parsed.segments.count) 段")
        }
    }

    private var statusLabel: String {
        switch speech.state {
        case .idle: return strings.text("Ready", "就绪")
        case .preparing: return strings.text("Preparing speech…", "正在准备语音…")
        case .previewing: return strings.text("Previewing…", "正在播放…")
        case .exporting: return strings.text("Exporting…", "正在导出…")
        case .stopping: return strings.text("Stopping…", "正在停止…")
        case .completed: return strings.text("Completed", "已完成")
        case .cancelled: return strings.text("Stopped", "已停止")
        case .failed(let message): return message
        }
    }

    @MainActor private func refresh() async {
        guard !refreshing, !busy else { return }
        refreshing = true
        defer { refreshing = false }
        do {
            try await speech.refresh()
            if !hasInitializedLanguage {
                let recommendation = VoiceRecommendation.best(
                    among: speech.voices,
                    preferredLanguages: appLanguagePreference.preferredVoiceLanguages
                )
                language = recommendation?.language ?? VoiceLanguage.systemDefault(
                    among: speech.voices,
                    preferredLanguages: appLanguagePreference.preferredVoiceLanguages
                ) ?? ""
                settings.voice = recommendation
                hasInitializedLanguage = true
            }
            if let voice = settings.voice, !speech.voices.contains(where: { $0.id == voice.id }) {
                errorMessage = strings.text(
                    "The selected Voice is no longer available. Choose a Voice before continuing.",
                    "所选声音已不可用。请先选择其他声音。"
                )
            }
            if !speech.capabilities.outputs.contains(where: { $0.container == output.container }),
               let first = speech.capabilities.outputs.first {
                output = ExportSettings(container: first.container)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    private func prepareWelcomeDocument() {
        guard fileURL == nil, document.text.isEmpty, !hasShownWelcomeDocument else { return }
        document.text = strings.welcomeText
        hasShownWelcomeDocument = true
    }

    private func authorize() {
        Task {
            do {
                try await speech.authorizePersonalVoice()
                showPersonalVoiceSettingsGuidance = speech.authorization == .denied
            }
            catch { errorMessage = error.localizedDescription }
        }
    }

    private func preview() {
        Task {
            do { try await speech.preview(text: document.text, settings: settings) }
            catch is CancellationError { }
            catch { errorMessage = error.localizedDescription }
        }
    }

    private func export() {
        let panel = NSSavePanel()
        panel.title = strings.text("Export Audio", "导出音频")
        panel.prompt = strings.text("Export", "导出")
        panel.nameFieldStringValue = (fileURL?.deletingPathExtension().lastPathComponent
            ?? strings.text("Untitled", "未命名")) + "." + output.container.rawValue
        panel.allowedContentTypes = [UTType(filenameExtension: output.container.rawValue)!]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        guard let window = NSApp.keyWindow else { return }
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                do { try await speech.export(text: document.text, settings: settings, output: output, to: url) }
                catch is CancellationError { }
                catch { errorMessage = error.localizedDescription }
            }
        }
    }
}
