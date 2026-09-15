import AppleSayCore
import Foundation
import SwiftUI

enum AppLanguagePreference: String, CaseIterable, Identifiable {
    static let defaultsKey = "interfaceLanguage"

    case system
    case english
    case simplifiedChinese

    var id: String { rawValue }

    var resolved: AppLanguage {
        switch self {
        case .english: return .english
        case .simplifiedChinese: return .simplifiedChinese
        case .system:
            for identifier in Locale.preferredLanguages {
                let language = Locale(identifier: identifier).language
                if language.languageCode?.identifier == "zh", language.script?.identifier != "Hant" {
                    return .simplifiedChinese
                }
                if language.languageCode?.identifier == "en" { return .english }
            }
            return .english
        }
    }
}

enum AppLanguage {
    case english
    case simplifiedChinese
}

struct AppStrings {
    let language: AppLanguage

    init(preferenceRawValue: String) {
        language = (AppLanguagePreference(rawValue: preferenceRawValue) ?? .system).resolved
    }

    func text(_ english: String, _ simplifiedChinese: String) -> String {
        language == .simplifiedChinese ? simplifiedChinese : english
    }

    var locale: Locale {
        Locale(identifier: language == .simplifiedChinese ? "zh-Hans" : "en")
    }

    var welcomeText: String {
        text(
            "Welcome to Apple Say. Press the Play button in the top-right corner to hear this sentence.",
            "欢迎使用 Apple Say。点击右上角的播放按钮，即可听到这句话。"
        )
    }

    func qualityName(_ quality: VoiceQuality) -> String {
        switch quality {
        case .legacy: return text("Legacy", "经典")
        case .compact: return text("Compact", "精简")
        case .standard: return text("Standard", "标准")
        case .enhanced: return text("Enhanced", "增强")
        case .premium: return text("Premium", "高级")
        }
    }
}

struct LanguageSettingsView: View {
    @AppStorage(AppLanguagePreference.defaultsKey) private var preferenceRawValue = AppLanguagePreference.system.rawValue

    private var strings: AppStrings { AppStrings(preferenceRawValue: preferenceRawValue) }

    var body: some View {
        Form {
            Picker(strings.text("Interface Language", "界面语言"), selection: $preferenceRawValue) {
                Text(strings.text("System Default", "跟随系统")).tag(AppLanguagePreference.system.rawValue)
                Text("English").tag(AppLanguagePreference.english.rawValue)
                Text("简体中文").tag(AppLanguagePreference.simplifiedChinese.rawValue)
            }
            Text(strings.text(
                "Interface labels update immediately. New documents use the selected language when choosing a recommended Voice.",
                "界面文字会立即更新。新文稿会根据所选语言推荐声音。"
            ))
            .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 470)
        .padding(.vertical, 8)
    }
}
