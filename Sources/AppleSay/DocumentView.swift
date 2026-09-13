import AppKit
import AVFAudio
import SwiftUI
import UniformTypeIdentifiers
import AppleSayCore

struct DocumentView: View {
    @Binding var document: SayDocument
    let fileURL: URL?
    @Environment(\.scenePhase) private var scenePhase
    @State private var speech = SpeechController(system: SystemSpeech())
    @State private var settings = SpeechSettings()
    @State private var output = ExportSettings()
    @State private var inspectorPresented = true
    @State private var language = ""
    @State private var errorMessage: String?
    @State private var refreshing = false

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
                .accessibilityLabel("Document text")
                .accessibilityHint("Enter Plain Text, LRC, or Enhanced LRC to speak.")
            Divider()
            statusBar
        }
        .frame(minWidth: 480, minHeight: 360)
        .inspector(isPresented: $inspectorPresented) {
            SpeechInspector(
                speech: speech, settings: $settings, output: $output, language: $language,
                authorize: authorize
            )
            .inspectorColumnWidth(min: 270, ideal: 300, max: 360)
            .disabled(busy || refreshing)
        }
        .toolbar {
            ToolbarItemGroup {
                Button(action: preview) { Label("Preview", systemImage: "play.fill") }
                    .disabled(!canPreview)
                    .help("Preview (⌘Return)")
                Button(action: speech.stop) { Label("Stop", systemImage: "stop.fill") }
                    .disabled(!busy)
                    .help("Stop (⌘.)")
                Button(action: export) { Label("Export", systemImage: "square.and.arrow.up") }
                    .disabled(!canExport)
                    .help("Export Audio (⇧⌘E)")
            }
            ToolbarItem(placement: .automatic) {
                Button { inspectorPresented.toggle() } label: {
                    Label("Speech Inspector", systemImage: "sidebar.right")
                }
                .help("Show or hide Speech Inspector (⌥⌘I)")
            }
        }
        .focusedSceneValue(\.speechActions, SpeechActions(
            preview: preview, stop: speech.stop, export: export,
            toggleInspector: { inspectorPresented.toggle() },
            canPreview: canPreview, canStop: busy, canExport: canExport
        ))
        .task { await refresh() }
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
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            Text(formatLabel)
                .help("Document format is detected automatically from its complete contents.")
            Spacer()
            if busy || refreshing { ProgressView().controlSize(.small) }
            Text(refreshing ? "Loading Voices…" : statusLabel)
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
        case .plainText: return "Plain Text"
        case .lrc: return "LRC · \(parsed.segments.count) Segments"
        case .enhancedLRC: return "Enhanced LRC · \(parsed.segments.count) Segments"
        }
    }

    private var statusLabel: String {
        switch speech.state {
        case .idle: return "Ready"
        case .preparing: return "Preparing speech…"
        case .previewing: return "Previewing…"
        case .exporting: return "Exporting…"
        case .stopping: return "Stopping…"
        case .completed: return "Completed"
        case .cancelled: return "Stopped"
        case .failed(let message): return message
        }
    }

    @MainActor private func refresh() async {
        guard !refreshing, !busy else { return }
        refreshing = true
        defer { refreshing = false }
        do {
            try await speech.refresh()
            if let voice = settings.voice, !speech.voices.contains(where: { $0.id == voice.id }) {
                errorMessage = "The selected Voice is no longer available. Choose a Voice before continuing."
            }
            if !speech.capabilities.outputs.contains(where: { $0.container == output.container }),
               let first = speech.capabilities.outputs.first {
                output = ExportSettings(container: first.container)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    private func authorize() {
        Task {
            do { try await speech.authorizePersonalVoice() }
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
        panel.title = "Export Audio"
        panel.prompt = "Export"
        panel.nameFieldStringValue = (fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled") + "." + output.container.rawValue
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
