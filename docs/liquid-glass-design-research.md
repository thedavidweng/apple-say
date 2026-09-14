# Liquid Glass design research for Apple Say

Research date: 2026-09-14. Sources are Apple first-party documentation and WWDC sessions only.

## Executive conclusion

The appropriate modernization is mostly subtraction. Apple defines Liquid Glass as a distinct functional layer for navigation and controls above content, not as a general-purpose decoration. Apple Say should rely on SwiftUI's standard window toolbar, inspector, forms, buttons, pickers, slider, toggle, and system materials, and add custom glass only if a genuinely custom top-level interactive control exists. The current bottom status labels are information, so giving each one a glass capsule falsely promotes them into controls and muddies hierarchy. [Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/) explicitly says to reserve glass for the navigation layer, keep tables/content in the content layer, and avoid glass on glass; the [HIG Materials guidance](https://developer.apple.com/design/human-interface-guidelines/materials) likewise says not to use Liquid Glass in the content layer.

## Recommended Apple Say structure

### Toolbar

Use the standard SwiftUI toolbar and let the system supply its Liquid Glass surface. Do not apply `glassEffect` to toolbar contents, and remove the explicit `.glassProminent` style from Preview unless product hierarchy truly calls for a persistent primary-action treatment. Apple says standard toolbar items receive the new appearance automatically, while tint is for semantic emphasis such as a call to action or next step, not visual decoration. [Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/) also recommends removing extra backgrounds that interfere with the system scroll-edge effect.

For this app, use two semantic groups:

1. A single Speech action group containing Preview, Stop, and Export. These all operate on the current Document and should read as one compact command cluster; Preview and Stop are two states of the same playback function.
2. A separately trailing inspector toggle. An inspector changes window structure rather than operating on the Document. Apple explicitly uses an inspector as an example of an action with distinct behavior that should remain separate.

This is a repo-specific application of Apple's rule, not a claim that every playback app must use this exact grouping. The normative rule is to group by function and frequency, minimize the number of groups (generally no more than three), and use spacers to express a true semantic break. See [HIG Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars), Apple's [Landmarks toolbar sample](https://developer.apple.com/documentation/swiftui/landmarks-refining-the-system-provided-glass-effect-in-toolbars), and [`ToolbarSpacer`](https://developer.apple.com/documentation/swiftui/toolbarspacer). A screenshot of Notes is supporting visual evidence, not an API or universal grouping mandate.

Keep all toolbar actions in the macOS menu bar too. HIG requires this because a Mac toolbar can be hidden or customized. Apple Say already exposes Preview, Stop, Export, and the inspector toggle as menu commands, so preserve that behavior. Use monochrome SF Symbols in the toolbar and retain concise hover help; Apple recommends familiar symbols and notes that macOS supplies button tooltips. [HIG Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) and [HIG Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons).

Do not title an empty Document window “Apple Say.” HIG says an app name is not a useful window title; use the Document name or a concise document state such as “Untitled.” [HIG Toolbars — Titles](https://developer.apple.com/design/human-interface-guidelines/toolbars).

### Bottom status information

Restore a quiet, flat bottom status bar: one horizontal row below the editor, separated by the system divider, with Plain Text/LRC format at leading and operational status at trailing. Keep the text secondary and non-button-shaped. The progress indicator can remain beside the transient status.

Apple calls a bottom bar on macOS rare but valid for a small amount of information directly related to window contents or selection, citing Finder's item count/status bar. It warns not to put critical information or actions there because the bottom edge can be obscured. Apple Say's detected Document format and “Ready/Previewing/Exporting” state fit that narrow informational purpose; actions do not. See [HIG Windows — macOS window anatomy](https://developer.apple.com/design/human-interface-guidelines/windows) and [HIG Layout — macOS](https://developer.apple.com/design/human-interface-guidelines/layout).

The labels themselves should remain ordinary `Text`, which correctly communicates static, noneditable information. Secondary system color is appropriate for supplemental text. [HIG Labels](https://developer.apple.com/design/human-interface-guidelines/labels). `safeAreaBar` may be useful when a custom bar must coordinate safe-area and scroll-edge behavior, but the API merely places a bar and adjusts scroll effects; it does not imply that every child needs a glass background. [`safeAreaBar`](https://developer.apple.com/documentation/swiftui/view/safeareabar(edge:alignment:spacing:content:)). For this editor, the conventional framed bottom row is the clearer Mac pattern.

### Inspector and controls

Keep SwiftUI's `.inspector(isPresented:)` and `.inspectorColumnWidth(...)`; a trailing inspector is the system model for auxiliary settings related to the current content, and the framework restores its presentation state. [`inspector(isPresented:content:)`](https://developer.apple.com/documentation/swiftui/view/inspector(isPresented:content:)). Apple describes the macOS 26 inspector as an edge-to-edge structural region with subtle layering that associates it with the current selection/content. [Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/) and [Build an AppKit app with the new design](https://developer.apple.com/videos/play/wwdc2025/310/).

Continue using a standard `Form`, `Section`, `Picker`, `LabeledContent`, `Slider`, `Toggle`, `DisclosureGroup`, and `Button`. Do not add manual glass to form sections, explanatory Personal Voice text, quality labels, or reset controls. SwiftUI's standard controls already adopt the platform appearance. In compact inspector layouts, use the existing small/medium control sizes where density needs tuning; Apple specifically retains rounded rectangles for mini, small, and medium Mac controls and recommends `controlSize` for dense inspectors and popovers. [Build a SwiftUI app with the new design — Controls](https://developer.apple.com/videos/play/wwdc2025/323/).

### Scroll edges, content, and accessibility

Do not add a scroll-edge effect merely as decoration. Apple says it exists to preserve legibility where scrolling content passes under floating UI, to apply one effect per view, and not to stack styles. If the editor actually scrolls beneath the title toolbar, let the system's automatic effect work and remove custom toolbar backgrounds; customize it only after testing demonstrates a clarity problem. [Get to know the new design system](https://developer.apple.com/videos/play/wwdc2025/356/).

Prefer native glass and system controls over manually composited translucency. System Liquid Glass automatically responds to Reduce Transparency, Increase Contrast, Reduce Motion, content brightness, and inactive-window state. Validate light/dark appearances, increased contrast, reduced transparency, reduced motion, keyboard-only operation, VoiceOver labels, narrow windows, and both macOS 26 and 27. [Meet Liquid Glass — legibility and accessibility](https://developer.apple.com/videos/play/wwdc2025/219/).

## Engineering and availability

Apple Say targets macOS 14, while `glassEffect`, glass/glass-prominent button styles, `ToolbarSpacer`, and `safeAreaBar` are macOS 26 APIs. Keep `#available(macOS 26.0, *)` only around APIs that genuinely require it. Prefer one common semantic hierarchy built from long-standing standard components; let those components acquire the appropriate macOS 14–27 appearance from the runtime. Do not maintain a separate custom “Liquid Glass layout” and legacy layout when the only difference is decorative styling. API availability is documented by Apple on [`glassEffect`](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)), [`GlassButtonStyle`](https://developer.apple.com/documentation/swiftui/glassbuttonstyle), [`ToolbarSpacer`](https://developer.apple.com/documentation/swiftui/toolbarspacer), and [`safeAreaBar`](https://developer.apple.com/documentation/swiftui/view/safeareabar(edge:alignment:spacing:content:)).

Build with the new SDK to receive the new appearance from standard components; Apple describes this as the primary adoption path. Custom Liquid Glass is intended for important custom controls that truly float above content, such as Maps controls—not for recreating system surfaces. [Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/).

## macOS 26 versus macOS 27

### Public macOS 26 baseline

The WWDC25 material above is the public foundation: Liquid Glass is a functional control/navigation layer; standard structures and controls adopt it; toolbar grouping is semantic; inspectors are structural; scroll-edge effects protect legibility; content and informational labels remain content.

### Public macOS 27 updates

Apple has now published official WWDC26 guidance for macOS 27, so macOS 27 itself is not speculative. Apple says existing Liquid Glass adoption receives the refined appearance automatically, including the user-adjustable glass tint, edge-to-edge sidebars, uniform toolbar behavior, and updated inactive-window treatment. The new Mac interactive glass response is for buttons, controls, or containers of interactive controls, and Apple cautions that “a little goes a long way.” [What's new in SwiftUI (WWDC26)](https://developer.apple.com/videos/play/wwdc2026/269/), [Modernize your AppKit app (WWDC26)](https://developer.apple.com/videos/play/wwdc2026/289/), and [Platforms State of the Union (WWDC26)](https://developer.apple.com/videos/play/wwdc2026/102/).

For Apple Say, this reinforces the same design: do not add macOS 27-specific glass to status labels or inspector content. Let standard controls update automatically. Xcode 27 also adds toolbar visibility-priority, explicit overflow, and pinned-placement APIs for constrained widths; consider them only after the app builds with Xcode 27 and a resize test shows that an essential action is lost. Apple Say's installed development environment was Xcode 26.6 with macOS SDK 26.5 at research time, so no production recommendation here assumes unverified Xcode 27 declarations. [What's new in SwiftUI — toolbar resizability](https://developer.apple.com/videos/play/wwdc2026/269/).

### Unsupported assumptions to avoid

- Do not infer exact universal spacing, corner radii, opacity, or grouping solely from a screenshot of Notes; use system components and semantic APIs.
- Do not assume every capsule is Liquid Glass or that every Liquid Glass surface denotes the same role.
- Do not assume an informational label should animate or respond like a control on macOS 27.
- Do not copy a future-system visual with custom drawing on macOS 14–25. Preserve semantic structure and let each OS render its own native appearance.

## Implementation checklist for the production change

- Remove the two `glassEffect(.regular, in: .capsule)` modifiers from bottom status text and use one flat status row.
- Remove explicit prominent glass styling from Preview; put Preview, Stop, and Export in one standard `ToolbarItemGroup`.
- Use one fixed toolbar separation before the trailing inspector toggle; avoid any split within the Speech action cluster.
- Preserve the menu commands, disabled states, keyboard shortcuts, help text, and accessibility labels.
- Use a Document title (“Untitled” or filename), never the app name.
- Keep the standard inspector and form controls; tune `controlSize` only where the native inspector is demonstrably too loose.
- Test appearance and interaction on macOS 14/15, 26, and 27 rather than trying to make earlier releases imitate Liquid Glass.
