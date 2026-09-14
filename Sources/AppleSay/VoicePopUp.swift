import AppKit
import SwiftUI
import AppleSayCore

enum VoiceManagement {
    enum Destination { case voices, personalVoice }

    @MainActor static func open(_ destination: Destination) {
        let anchor = destination == .voices ? "AX_SPOKEN_VOICE" : "PersonalVoice"
        let url = URL(string: "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?\(anchor)")!
        if !NSWorkspace.shared.open(url) {
            let strings = AppStrings(preferenceRawValue:
                UserDefaults.standard.string(forKey: AppLanguagePreference.defaultsKey) ?? AppLanguagePreference.system.rawValue)
            let alert = NSAlert()
            alert.messageText = strings.text("System Settings could not be opened.", "无法打开系统设置。")
            alert.informativeText = strings.text(
                "Open System Settings → Accessibility, then choose Read & Speak or Personal Voice.",
                "请打开“系统设置”→“辅助功能”，然后选择“朗读内容”或“个人声音”。"
            )
            alert.runModal()
        }
    }
}

final class TruncatingPopUpButton: NSPopUpButton {
    override var intrinsicContentSize: NSSize {
        let base = super.intrinsicContentSize
        guard let title = selectedItem?.title ?? titleOfSelectedItem else { return base }
        let font = self.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let titleWidth = (title as NSString).size(withAttributes: [.font: font]).width
        let width = min(max(titleWidth + 36, 120), 190)
        return NSSize(width: width, height: base.height)
    }
}

/// AppKit's pop-up preserves native keyboard/menu behavior while allowing management
/// actions after the selectable Voices, which SwiftUI Picker does not represent.
struct VoicePopUp: NSViewRepresentable {
    var voices: [Voice]
    @Binding var selection: Voice?
    let strings: AppStrings

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = TruncatingPopUpButton(frame: .zero, pullsDown: false)
        context.coordinator.button = button
        button.setAccessibilityLabel(strings.text("Voice", "声音"))
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        button.lineBreakMode = .byTruncatingTail
        (button.cell as? NSPopUpButtonCell)?.lineBreakMode = .byTruncatingTail
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.parent = self
        button.removeAllItems()
        button.setAccessibilityLabel(strings.text("Voice", "声音"))
        let defaultItem = NSMenuItem(
            title: strings.text("System Voice", "系统声音"),
            action: #selector(Coordinator.selectVoice(_:)), keyEquivalent: ""
        )
        defaultItem.target = context.coordinator
        button.menu?.addItem(defaultItem)
        button.menu?.addItem(.separator())
        var listedVoices = voices
        // A locale filter narrows choices without changing the active speech settings.
        if let selection, !listedVoices.contains(where: { $0.id == selection.id }) {
            listedVoices.insert(selection, at: 0)
        }
        for voice in listedVoices {
            let item = NSMenuItem(
                title: title(for: voice),
                action: #selector(Coordinator.selectVoice(_:)), keyEquivalent: ""
            )
            item.representedObject = voice.id
            item.target = context.coordinator
            button.menu?.addItem(item)
            if voice.id == selection?.id { button.select(item) }
        }
        button.menu?.addItem(.separator())
        for (title, action) in [
            (strings.text("Add Voices…", "添加声音…"), #selector(Coordinator.addVoices)),
            (strings.text("Personal Voice Settings…", "个人声音设置…"), #selector(Coordinator.personalVoiceSettings))
        ] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = context.coordinator
            button.menu?.addItem(item)
        }
        if selection == nil { button.select(defaultItem) }
        button.isEnabled = context.environment.isEnabled
        button.invalidateIntrinsicContentSize()
    }

    private func title(for voice: Voice) -> String {
        var title = voice.name
        if voice.isPersonal {
            title += strings.text(" (Personal Voice)", "（个人声音）")
        } else if voice.isNovelty {
            title += strings.text(" (Novelty)", "（趣味声音）")
        } else {
            switch voice.quality {
            case .premium:
                title += strings.text(" (Premium)", "（高级）")
            case .enhanced:
                title += strings.text(" (Enhanced)", "（增强）")
            case .compact:
                title += strings.text(" (Compact)", "（精简）")
            case .legacy:
                title += strings.text(" (Legacy)", "（经典）")
            case .standard:
                break
            }
        }
        return title
    }

    @MainActor final class Coordinator: NSObject {
        var parent: VoicePopUp
        weak var button: NSPopUpButton?
        init(_ parent: VoicePopUp) { self.parent = parent }

        @objc func selectVoice(_ item: NSMenuItem) {
            guard let id = item.representedObject as? String else {
                parent.selection = nil
                return
            }
            if let voice = parent.voices.first(where: { $0.id == id }) { parent.selection = voice }
        }

        private func restoreSelection() {
            let item = button?.itemArray.first {
                ($0.representedObject as? String) == parent.selection?.id && !$0.isSeparatorItem
            }
            button?.select(item)
        }

        @objc func addVoices() {
            restoreSelection()
            VoiceManagement.open(.voices)
        }
        @objc func personalVoiceSettings() {
            restoreSelection()
            VoiceManagement.open(.personalVoice)
        }
    }
}
