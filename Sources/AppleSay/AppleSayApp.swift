import SwiftUI
import UniformTypeIdentifiers
import AppleSayCore

extension UTType {
    static let lrc = UTType(importedAs: "com.thedavidweng.apple-say.lrc", conformingTo: .plainText)
}

struct SayDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .lrc] }
    static var writableContentTypes: [UTType] { [.plainText, .lrc] }
    var text = ""

    init() {}

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct SpeechActions {
    var preview: () -> Void
    var stop: () -> Void
    var export: () -> Void
    var toggleInspector: () -> Void
    var canPreview: Bool
    var canStop: Bool
    var canExport: Bool
}

private struct SpeechActionsKey: FocusedValueKey {
    typealias Value = SpeechActions
}

extension FocusedValues {
    var speechActions: SpeechActions? {
        get { self[SpeechActionsKey.self] }
        set { self[SpeechActionsKey.self] = newValue }
    }
}

@main
struct AppleSayApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: SayDocument()) { configuration in
            DocumentView(document: configuration.$document, fileURL: configuration.fileURL)
        }
        .defaultSize(width: 960, height: 660)
        .commands { SpeechCommands() }
    }
}

struct SpeechCommands: Commands {
    @FocusedValue(\.speechActions) private var actions

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Button("Export Audio…") { actions?.export() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(actions?.canExport != true)
        }
        CommandMenu("Speech") {
            Button("Preview") { actions?.preview() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(actions?.canPreview != true)
            Button("Stop") { actions?.stop() }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(actions?.canStop != true)
            Divider()
            Button("Add Voices…") { VoiceManagement.open(.voices) }
            Button("Personal Voice Settings…") { VoiceManagement.open(.personalVoice) }
        }
        CommandGroup(after: .sidebar) {
            Button("Show or Hide Speech Inspector") { actions?.toggleInspector() }
                .keyboardShortcut("i", modifiers: [.command, .option])
                .disabled(actions == nil)
        }
    }
}
