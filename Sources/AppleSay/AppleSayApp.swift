import SwiftUI
import UniformTypeIdentifiers
import AppleSayCore

extension UTType {
    static let lrc = UTType(importedAs: "com.thedavidweng.apple-say.lrc", conformingTo: .plainText)
}

struct DocumentFileActions {
    var newDocument: () -> Void
    var openDocument: () -> Void
    var saveDocument: () -> Void
}

private struct DocumentFileActionsKey: FocusedValueKey {
    typealias Value = DocumentFileActions
}

extension FocusedValues {
    var documentFileActions: DocumentFileActions? {
        get { self[DocumentFileActionsKey.self] }
        set { self[DocumentFileActionsKey.self] = newValue }
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
        WindowGroup {
            DocumentView()
        }
        .defaultSize(width: 960, height: 660)
        .commands {
            ApplicationCommands()
            FileCommands()
            SpeechCommands()
        }

        Settings {
            LanguageSettingsView()
        }
    }
}

struct ApplicationCommands: Commands {
    @AppStorage(AppLanguagePreference.defaultsKey) private var languagePreference = AppLanguagePreference.system.rawValue

    private var strings: AppStrings { AppStrings(preferenceRawValue: languagePreference) }

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(strings.text("About Apple Say", "关于 Apple Say")) {
                NSApp.orderFrontStandardAboutPanel(nil)
            }
        }
    }
}

struct FileCommands: Commands {
    @FocusedValue(\.documentFileActions) private var fileActions
    @AppStorage(AppLanguagePreference.defaultsKey) private var languagePreference = AppLanguagePreference.system.rawValue

    private var strings: AppStrings { AppStrings(preferenceRawValue: languagePreference) }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(strings.text("New", "新建")) { fileActions?.newDocument() }
                .keyboardShortcut("n", modifiers: .command)
            Button(strings.text("Open…", "打开…")) { fileActions?.openDocument() }
                .keyboardShortcut("o", modifiers: .command)
        }
        CommandGroup(replacing: .saveItem) {
            Button(strings.text("Save…", "存储…")) { fileActions?.saveDocument() }
                .keyboardShortcut("s", modifiers: .command)
        }
    }
}

struct SpeechCommands: Commands {
    @FocusedValue(\.speechActions) private var actions
    @AppStorage(AppLanguagePreference.defaultsKey) private var languagePreference = AppLanguagePreference.system.rawValue

    private var strings: AppStrings { AppStrings(preferenceRawValue: languagePreference) }

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Button(strings.text("Export Audio…", "导出音频…")) { actions?.export() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(actions?.canExport != true)
        }
        CommandMenu(strings.text("Speech", "语音")) {
            Button(strings.text("Preview", "播放")) { actions?.preview() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(actions?.canPreview != true)
            Button(strings.text("Stop", "停止")) { actions?.stop() }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(actions?.canStop != true)
            Divider()
            Button(strings.text("Add Voices…", "添加声音…")) { VoiceManagement.open(.voices) }
            Button(strings.text("Personal Voice Settings…", "个人声音设置…")) { VoiceManagement.open(.personalVoice) }
        }
        CommandGroup(after: .sidebar) {
            Button(strings.text("Show or Hide Speech Inspector", "显示或隐藏语音检查器")) { actions?.toggleInspector() }
                .keyboardShortcut("i", modifiers: [.command, .option])
                .disabled(actions == nil)
        }
    }
}
