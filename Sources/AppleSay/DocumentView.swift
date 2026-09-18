import AppKit
import AVFAudio
import SwiftUI
import UniformTypeIdentifiers
import AppleSayCore

/// SwiftUI's content margins inset the scroll view background on macOS. Using
/// NSTextView's native text-container inset keeps the document canvas edge-to-edge
/// while giving the insertion point and text a comfortable internal margin.
private struct DocumentTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var requestedReplacement: String?
    @Binding var writingToolsActive: Bool
    @Binding var composingText: Bool
    let accessibilityLabel: String
    let accessibilityHelp: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = textView(in: scrollView)

        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: 16)
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        configureTextContainer(textView)
        configureWritingTools(textView)
        configureWritingToolsMenu(textView)
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.string = text
        textView.delegate = context.coordinator
        textView.setAccessibilityLabel(accessibilityLabel)
        textView.setAccessibilityHelp(accessibilityHelp)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        let textView = textView(in: scrollView)
        configureTextContainer(textView)
        configureWritingTools(textView)
        configureWritingToolsMenu(textView)
        if let replacement = requestedReplacement {
            let fullRange = NSRange(location: 0, length: textView.string.utf16.count)
            if textView.shouldChangeText(in: fullRange, replacementString: replacement) {
                textView.replaceCharacters(in: fullRange, with: replacement)
                textView.didChangeText()
            }
            DispatchQueue.main.async { requestedReplacement = nil }
            return
        }
        if !textView.hasMarkedText(), textView.string != text {
            textView.string = text
        }
        textView.setAccessibilityLabel(accessibilityLabel)
        textView.setAccessibilityHelp(accessibilityHelp)
    }

    private func configureTextContainer(_ textView: NSTextView) {
        textView.textContainerInset = NSSize(width: 20, height: 16)
        textView.textContainer?.lineFragmentPadding = 0
    }

    private func configureWritingTools(_ textView: NSTextView) {
        if #available(macOS 15.0, *) {
            textView.writingToolsBehavior = .default
            textView.allowedWritingToolsResultOptions = .plainText
        }
    }

    private func configureWritingToolsMenu(_ textView: NSTextView) {
        guard #available(macOS 15.2, *), let menu = textView.menu,
              let writingToolsItem = NSMenuItem.writingToolsItems.first,
              !menu.items.contains(where: { $0.identifier == writingToolsItem.identifier }) else { return }
        // NSTextView does not consistently perform its advertised automatic
        // insertion, so install AppKit's own standard Writing Tools submenu.
        menu.automaticallyInsertsWritingToolsItems = false
        menu.insertItem(writingToolsItem.copy() as! NSMenuItem, at: 0)
        menu.insertItem(.separator(), at: 1)
    }

    private func textView(in scrollView: NSScrollView) -> NSTextView {
        guard let textView = scrollView.documentView as? NSTextView else {
            preconditionFailure("NSTextView.scrollableTextView() must contain an NSTextView document view")
        }
        return textView
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: DocumentTextEditor

        init(_ parent: DocumentTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.composingText = textView.hasMarkedText()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            // IME pre-edit text lives in NSTextView's marked range before it is
            // committed to the SwiftUI binding, so selection changes own this state.
            parent.composingText = textView.hasMarkedText()
        }

        @available(macOS 15.0, *)
        func textViewWritingToolsWillBegin(_ textView: NSTextView) {
            parent.writingToolsActive = true
        }

        @available(macOS 15.0, *)
        func textViewWritingToolsDidEnd(_ textView: NSTextView) {
            parent.writingToolsActive = false
        }

        @available(macOS 15.0, *)
        func textView(
            _ textView: NSTextView,
            writingToolsIgnoredRangesInEnclosingRange enclosingRange: NSRange
        ) -> [NSValue] {
            TimedTextMarkup.ranges(in: textView.string, intersecting: enclosingRange).map(NSValue.init(range:))
        }
    }
}

struct DocumentView: View {
    @State private var text = ""
    @State private var fileURL: URL?
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
    @State private var requestedReplacement: String?
    @State private var translationSuggestion: TranslationSuggestion?
    @State private var translationRequest: TranslationRequest?
    @State private var translationProposal: TranslationProposal?
    @State private var dismissedTranslationTarget: String?
    @State private var translating = false
    @State private var writingToolsActive = false
    @State private var composingText = false

    init(text: String = "", fileURL: URL? = nil) {
        _text = State(initialValue: text)
        _fileURL = State(initialValue: fileURL)
    }

    private var strings: AppStrings { AppStrings(preferenceRawValue: languagePreference) }
    private var busy: Bool { speech.state.isActive }

    private var hasText: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var selectedVoiceAvailable: Bool {
        settings.voice.map { selected in speech.voices.contains { $0.id == selected.id } } ?? true
    }
    private var canPreview: Bool {
        hasText && !busy && !writingToolsActive && selectedVoiceAvailable && !speech.voices.isEmpty
    }
    private var canExport: Bool { canPreview && !speech.capabilities.outputs.isEmpty }
    private var isWelcomePromptActive: Bool { fileURL == nil && text == strings.welcomeText && !busy }
    private var translationTargetIdentifier: String { settings.voice?.language ?? language }

    var body: some View {
        documentCanvas
        .frame(minWidth: 480, minHeight: 360)
        .navigationTitle(fileURL?.lastPathComponent ?? strings.text("Untitled", "未命名"))
        .inspector(isPresented: $inspectorPresented) {
            SpeechInspector(
                speech: speech, settings: $settings, output: $output, language: $language,
                strings: strings, authorize: authorize
            )
            .inspectorColumnWidth(min: 270, ideal: 300, max: 360)
            .disabled(busy || (refreshing && speech.voices.isEmpty))
        }
        .toolbar { speechToolbar }
        .focusedSceneValue(\.speechActions, SpeechActions(
            preview: preview, stop: speech.stop, export: export,
            toggleInspector: { inspectorPresented.toggle() },
            canPreview: canPreview, canStop: busy, canExport: canExport
        ))
        .focusedSceneValue(\.documentFileActions, DocumentFileActions(
            newDocument: newDocument,
            openDocument: openFile,
            saveDocument: saveFile
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
        .onOpenURL { url in
            loadFile(from: url)
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    loadFile(from: url)
                }
            }
            return true
        }
        .onDisappear { speech.stop() }
        .task(id: TranslationDetectionInput(
            document: text,
            targetIdentifier: translationTargetIdentifier,
            dismissedTargetIdentifier: dismissedTranslationTarget,
            writingToolsActive: writingToolsActive
        )) {
            await detectTranslationNeed()
        }
        .overlay { translationRunner }
        .sheet(item: $translationProposal) { proposal in
            TranslationReviewSheet(
                proposal: proposal,
                strings: strings,
                cancel: { translationProposal = nil },
                replace: {
                    requestedReplacement = proposal.translated
                    translationProposal = nil
                }
            )
        }
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

    private var documentCanvas: some View {
        VStack(spacing: 0) {
            documentEditor
            if let translationSuggestion, !writingToolsActive {
                Divider()
                translationBanner(translationSuggestion)
            }
            Divider()
            statusBar
        }
    }

    private var documentEditor: some View {
        ZStack(alignment: .topLeading) {
            DocumentTextEditor(
                text: $text,
                requestedReplacement: $requestedReplacement,
                writingToolsActive: $writingToolsActive,
                composingText: $composingText,
                accessibilityLabel: strings.text("Document text", "文稿文本"),
                accessibilityHelp: strings.text(
                    "Enter Plain Text, LRC, or Enhanced LRC to speak.",
                    "输入纯文本、LRC 或增强型 LRC 后即可播放。"
                )
            )
            if text.isEmpty && !composingText {
                Text(strings.text("Enter text to speak…", "输入要朗读的文本…"))
                    .font(.system(size: 16))
                    .foregroundStyle(Color(nsColor: .placeholderTextColor))
                    .padding(.top, 16)
                    .padding(.leading, 25)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func translationBanner(_ suggestion: TranslationSuggestion) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "translate")
                .foregroundStyle(.secondary)
            Text(strings.text(
                "This Document appears to be in \(suggestion.sourceName).",
                "此文稿似乎是\(suggestion.sourceName)。"
            ))
            Spacer()
            if translating { ProgressView().controlSize(.small) }
            Button(strings.text(
                "Translate to \(suggestion.targetName)…",
                "翻译为\(suggestion.targetName)…"
            )) {
                translating = true
                translationRequest = TranslationRequest(
                    source: suggestion.source,
                    target: suggestion.target,
                    document: text
                )
            }
            .disabled(translating || busy || writingToolsActive)
            Button {
                dismissedTranslationTarget = translationTargetIdentifier
                translationSuggestion = nil
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(strings.text("Dismiss", "关闭"))
            .disabled(translating)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder private var translationRunner: some View {
        if #available(macOS 15.0, *), let translationRequest {
            TranslationRunner(request: translationRequest) { result in
                Task { @MainActor in
                    translating = false
                    self.translationRequest = nil
                    switch result {
                    case .success(let translated):
                        guard text == translationRequest.document else {
                            errorMessage = strings.text(
                                "The Document changed while it was being translated. Try again with the current text.",
                                "翻译期间文稿已发生变化。请使用当前文本重试。"
                            )
                            return
                        }
                        let targetName = translationSuggestion?.targetName
                            ?? translationRequest.target.minimalIdentifier
                        translationProposal = TranslationProposal(
                            original: translationRequest.document,
                            translated: translated,
                            targetName: targetName
                        )
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    @ToolbarContentBuilder private var speechToolbar: some ToolbarContent {
        if #available(macOS 26.0, *) {
            ToolbarItemGroup {
                playButton
                stopButton
                exportButton
            }
            ToolbarSpacer(.fixed)
            ToolbarItem(placement: .automatic) {
                inspectorButton
            }
        } else {
            ToolbarItemGroup {
                playButton
                stopButton
                exportButton
                inspectorButton
            }
        }
    }

    private var playButtonHelp: String {
        isWelcomePromptActive
            ? strings.text("Click to listen to Apple Say (⌘Return)", "点击试听 Apple Say（⌘Return）")
            : strings.text("Preview (⌘Return)", "播放（⌘Return）")
    }

    @ViewBuilder private var playButton: some View {
        Button(action: preview) {
            Label {
                Text(strings.text("Preview", "播放"))
            } icon: {
                Image(systemName: "play.fill")
                    .symbolEffect(.pulse, options: .repeating, isActive: isWelcomePromptActive)
            }
        }
        .disabled(!canPreview)
        .help(playButtonHelp)
    }

    private var stopButton: some View {
        Button(action: speech.stop) { Label(strings.text("Stop", "停止"), systemImage: "stop.fill") }
            .disabled(!busy)
            .help(strings.text("Stop (⌘.)", "停止（⌘.）"))
    }

    private var exportButton: some View {
        Button(action: export) { Label(strings.text("Export", "导出"), systemImage: "square.and.arrow.up") }
            .disabled(!canExport)
            .help(strings.text("Export Audio (⇧⌘E)", "导出音频（⇧⌘E）"))
    }

    private var inspectorButton: some View {
        Button { inspectorPresented.toggle() } label: {
            Label(strings.text("Speech Inspector", "语音检查器"), systemImage: "sidebar.right")
        }
        .help(strings.text("Show or hide Speech Inspector (⌥⌘I)", "显示或隐藏语音检查器（⌥⌘I）"))
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            Text(formatLabel)
                .help(strings.text(
                    "Document format is detected automatically from its complete contents.",
                    "Apple Say 会根据文稿的完整内容自动识别格式。"
                ))
            Spacer()
            if busy || (refreshing && speech.voices.isEmpty) { ProgressView().controlSize(.small) }
            Text(refreshing && speech.voices.isEmpty ? strings.text("Loading Voices…", "正在载入声音…") : statusLabel)
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
        let parsed = SpeechController.analyze(text)
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

    @MainActor private func detectTranslationNeed() async {
        translationSuggestion = nil
        guard #available(macOS 15.0, *),
              !writingToolsActive,
              translationTargetIdentifier != dismissedTranslationTarget else { return }
        do {
            try await Task.sleep(for: .milliseconds(600))
            try Task.checkCancellation()
            translationSuggestion = await NativeLanguageFeatures.translationSuggestion(
                for: text,
                targetIdentifier: translationTargetIdentifier,
                displayLocale: strings.locale
            )
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor private func refresh() async {
        guard !refreshing, !busy else { return }
        refreshing = true
        defer { refreshing = false }
        do {
            try await speech.refresh()
            if !hasInitializedLanguage {
                settings.voice = nil
                language = ""
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
        guard fileURL == nil, text.isEmpty, !hasShownWelcomeDocument else { return }
        text = strings.welcomeText
        hasShownWelcomeDocument = true
    }

    private func newDocument() {
        text = ""
        fileURL = nil
        dismissedTranslationTarget = nil
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.title = strings.text("Open Document", "打开文稿")
        panel.allowedContentTypes = [.plainText, .lrc]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard let window = NSApp.keyWindow else { return }
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            loadFile(from: url)
        }
    }

    private func loadFile(from url: URL) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            text = content
            fileURL = url
            dismissedTranslationTarget = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveFile() {
        let panel = NSSavePanel()
        panel.title = strings.text("Save Document", "存储文稿")
        panel.nameFieldStringValue = fileURL?.lastPathComponent ?? (strings.text("Untitled", "未命名") + ".txt")
        panel.allowedContentTypes = [.plainText, .lrc]
        panel.canCreateDirectories = true
        guard let window = NSApp.keyWindow else { return }
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
                fileURL = url
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func authorize() {
        Task {
            do {
                try await speech.authorizePersonalVoice()
                showPersonalVoiceSettingsGuidance = speech.authorization == .denied
            } catch { errorMessage = error.localizedDescription }
        }
    }

    private func preview() {
        Task {
            do {
                try await speech.preview(text: text, settings: settings)
            } catch is CancellationError {
            } catch {
                errorMessage = error.localizedDescription
            }
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
                do {
                    try await speech.export(text: text, settings: settings, output: output, to: url)
                } catch is CancellationError {
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
