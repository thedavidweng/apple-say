import SwiftUI
import UniformTypeIdentifiers
import AppleSayCore

extension UTType {
    static let lrc = UTType(importedAs: "com.thedavidweng.apple-say.lrc", conformingTo: .plainText)
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
    @FocusedValue(DocumentSession.self) private var session
    @AppStorage(AppLanguagePreference.defaultsKey) private var languagePreference = AppLanguagePreference.system.rawValue

    private var strings: AppStrings { AppStrings(preferenceRawValue: languagePreference) }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(strings.text("New", "新建")) { session?.newDocument() }
                .keyboardShortcut("n", modifiers: .command)
            Button(strings.text("Open…", "打开…")) { session?.openFile(strings) }
                .keyboardShortcut("o", modifiers: .command)
        }
        CommandGroup(replacing: .saveItem) {
            Button(strings.text("Save…", "存储…")) { session?.saveFile(strings) }
                .keyboardShortcut("s", modifiers: .command)
        }
    }
}

struct SpeechCommands: Commands {
    @FocusedValue(DocumentSession.self) private var session
    @AppStorage(AppLanguagePreference.defaultsKey) private var languagePreference = AppLanguagePreference.system.rawValue

    private var strings: AppStrings { AppStrings(preferenceRawValue: languagePreference) }

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Button(strings.text("Export Audio…", "导出音频…")) { session?.export(strings) }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(session?.canExport != true)
        }
        CommandMenu(strings.text("Speech", "语音")) {
            Button(strings.text("Preview", "播放")) { session?.preview() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(session?.canPreview != true)
            Button(strings.text("Stop", "停止")) { session?.speech.stop() }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(session?.busy != true)
            Divider()
            Button(strings.text("Add Voices…", "添加声音…")) { VoiceManagement.open(.voices) }
            Button(strings.text("Personal Voice Settings…", "个人声音设置…")) { VoiceManagement.open(.personalVoice) }
        }
        CommandGroup(after: .sidebar) {
            Button(strings.text("Show or Hide Speech Inspector", "显示或隐藏语音检查器")) { session?.inspectorPresented.toggle() }
                .keyboardShortcut("i", modifiers: [.command, .option])
                .disabled(session == nil)
        }
    }
}
