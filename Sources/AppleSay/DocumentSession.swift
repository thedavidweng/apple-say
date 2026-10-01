import AppKit
import Observation
import UniformTypeIdentifiers
import AppleSayCore

/// Scene-owned Document state. Menu commands receive this instance as a focused
/// value, so SwiftUI compares it by reference instead of by uncomparable closures.
@MainActor @Observable final class DocumentSession {
    let speech = SpeechController(system: SystemSpeech())
    var text = "" {
        didSet { parsedDocument = SpeechController.analyze(text) }
    }
    /// Parsing a long LRC Document takes milliseconds, so it runs once per text change
    /// rather than on every view update caused by unrelated state such as Speech Settings.
    private(set) var parsedDocument = SpeechController.analyze("")
    var fileURL: URL?
    var settings = SpeechSettings()
    var output = ExportSettings()
    var inspectorPresented = true
    var errorMessage: String?
    var dismissedTranslationTarget: String?
    var writingToolsActive = false

    var busy: Bool { speech.state.isActive }
    var hasText: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var canPreview: Bool {
        let selectedVoiceAvailable = settings.voice.map { selected in
            speech.voices.contains { $0.id == selected.id }
        } ?? true
        return hasText && !busy && !writingToolsActive && selectedVoiceAvailable && !speech.voices.isEmpty
    }
    var canExport: Bool { canPreview && !speech.capabilities.outputs.isEmpty }
    var showsError: Bool {
        get { errorMessage != nil }
        set { if !newValue { errorMessage = nil } }
    }

    func newDocument() {
        text = ""
        fileURL = nil
        dismissedTranslationTarget = nil
    }

    func openFile(_ strings: AppStrings) {
        let panel = NSOpenPanel()
        panel.title = strings.text("Open Document", "打开文稿")
        panel.allowedContentTypes = [.plainText, .lrc]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard let window = NSApp.keyWindow else { return }
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            self.loadFile(from: url)
        }
    }

    func loadFile(from url: URL) {
        do {
            text = try String(contentsOf: url, encoding: .utf8)
            fileURL = url
            dismissedTranslationTarget = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveFile(_ strings: AppStrings) {
        let panel = NSSavePanel()
        panel.title = strings.text("Save Document", "存储文稿")
        panel.nameFieldStringValue = fileURL?.lastPathComponent ?? (strings.text("Untitled", "未命名") + ".txt")
        panel.allowedContentTypes = [.plainText, .lrc]
        panel.canCreateDirectories = true
        guard let window = NSApp.keyWindow else { return }
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try self.text.write(to: url, atomically: true, encoding: .utf8)
                self.fileURL = url
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func preview() {
        Task {
            do {
                try await speech.preview(text: text, settings: settings)
            } catch is CancellationError {
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func export(_ strings: AppStrings) {
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
            Task {
                do {
                    try await self.speech.export(text: self.text, settings: self.settings, output: self.output, to: url)
                } catch is CancellationError {
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
