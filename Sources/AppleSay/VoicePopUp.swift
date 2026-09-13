import AppKit
import SwiftUI
import AppleSayCore

enum VoiceManagement {
    enum Destination { case voices, personalVoice }

    @MainActor static func open(_ destination: Destination) {
        let anchor = destination == .voices ? "SpokenContent" : "PersonalVoice"
        let url = URL(string: "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?\(anchor)")!
        if !NSWorkspace.shared.open(url) {
            let alert = NSAlert()
            alert.messageText = "System Settings could not be opened."
            alert.informativeText = "Open System Settings → Accessibility, then choose Read & Speak or Personal Voice."
            alert.runModal()
        }
    }
}

/// AppKit's pop-up preserves native keyboard/menu behavior while allowing management
/// actions after the selectable Voices, which SwiftUI Picker does not represent.
struct VoicePopUp: NSViewRepresentable {
    var voices: [Voice]
    @Binding var selection: Voice?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        context.coordinator.button = button
        button.setAccessibilityLabel("Voice")
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.parent = self
        button.removeAllItems()
        let defaultItem = NSMenuItem(title: "System Default", action: #selector(Coordinator.selectVoice(_:)), keyEquivalent: "")
        defaultItem.target = context.coordinator
        button.menu?.addItem(defaultItem)
        var listedVoices = voices
        // A locale filter narrows choices without changing the active speech settings.
        if let selection, !listedVoices.contains(where: { $0.id == selection.id }) {
            listedVoices.insert(selection, at: 0)
        }
        for voice in listedVoices {
            let item = NSMenuItem(
                title: voice.name + (voice.isPersonal ? " (Personal Voice)" : ""),
                action: #selector(Coordinator.selectVoice(_:)), keyEquivalent: ""
            )
            item.representedObject = voice.id
            item.target = context.coordinator
            button.menu?.addItem(item)
            if voice.id == selection?.id { button.select(item) }
        }
        button.menu?.addItem(.separator())
        for (title, action) in [
            ("Add Voices…", #selector(Coordinator.addVoices)),
            ("Personal Voice Settings…", #selector(Coordinator.personalVoiceSettings))
        ] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = context.coordinator
            button.menu?.addItem(item)
        }
        if selection == nil { button.select(defaultItem) }
        button.isEnabled = context.environment.isEnabled
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
