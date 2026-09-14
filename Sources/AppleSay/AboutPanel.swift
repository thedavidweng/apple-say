import AppKit
import SwiftUI

@MainActor
final class AboutPanelController: NSWindowController {
    static let shared = AboutPanelController()

    private init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 410),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: AboutPanelView())
        super.init(window: panel)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func present() {
        guard let window else { return }
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct AboutPanelView: View {
    private let bundle = Bundle.main
    @AppStorage(AppLanguagePreference.defaultsKey) private var languagePreference = AppLanguagePreference.system.rawValue

    private var strings: AppStrings { AppStrings(preferenceRawValue: languagePreference) }

    private var appName: String {
        bundleString("CFBundleDisplayName")
    }

    private var version: String {
        let shortVersion = bundleString("CFBundleShortVersionString")
        let build = bundleString("CFBundleVersion")
        return strings.text(
            "Version \(shortVersion) (\(build))",
            "版本 \(shortVersion) (\(build))"
        )
    }

    private var copyright: String {
        strings.text(
            "Copyright © 2026 David Weng. All rights reserved.",
            "版权所有 © 2026 David Weng。保留所有权利。"
        )
    }

    private func bundleString(_ key: String) -> String {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String else {
            preconditionFailure("Missing required bundle value: \(key)")
        }
        return value
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 54)

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 104, height: 104)

            Text(appName)
                .font(.system(size: 28, weight: .semibold))
                .padding(.top, 26)

            Text(version)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, 10)

            Spacer(minLength: 28)

            Text(copyright)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 56)
        }
        .frame(width: 560, height: 410)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(strings.text("About \(appName)", "关于 \(appName)"))
    }
}
