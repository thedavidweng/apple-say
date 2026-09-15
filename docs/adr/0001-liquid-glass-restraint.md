# ADR-0001: Standard system controls only, no custom Liquid Glass

Date: 2026-09-14

## Status

Accepted.

## Context

macOS 26 introduces Liquid Glass. Apple defines it as a functional layer for
navigation and controls above content, not as general-purpose decoration: reserve
glass for the navigation layer, keep content in the content layer, and avoid glass
on glass. Giving Apple Say's informational bottom status labels glass capsules
falsely promoted them into controls and muddied hierarchy.

Sources: [Meet Liquid Glass (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/219/),
[Build a SwiftUI app with the new design (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/323/),
[HIG Materials](https://developer.apple.com/design/human-interface-guidelines/materials).

## Decision

Apple Say uses only standard SwiftUI structures and controls, and lets each
supported macOS version render its own native appearance from one semantic layout:

- Toolbar: Preview, Stop, and Export form one Speech command cluster; a
  `ToolbarSpacer(.fixed)` separates the trailing inspector toggle. No custom glass
  or explicit prominent-glass styling on toolbar items.
- Every toolbar action is also a menu command with its shortcut, disabled state,
  hover help, and accessibility label preserved, because a Mac toolbar can be
  hidden or customized.
- Bottom status row: plain secondary `Text`, document format leading and
  operational status trailing, never button-shaped. Actions never live there
  because the bottom edge can be obscured.
- Window title is the document name or "Untitled", never the app name.
- Standard `.inspector` plus `Form`-based controls for settings; no manual glass on
  form sections, explanatory text, quality labels, or reset controls.
- No custom scroll-edge effects or toolbar backgrounds; the system effect handles
  content passing under the toolbar.
- `#available(macOS 26.0, *)` only around APIs that genuinely require it
  (for example `ToolbarSpacer`); no parallel legacy/glass layouts, and no attempt
  to imitate macOS 26/27 visuals on macOS 14–25.

## Consequences

- Each supported macOS version renders its own native appearance from one semantic
  layout; accessibility behavior (Reduce Transparency, Increase Contrast, Reduce
  Motion, inactive-window state) is inherited from system controls.
- Xcode 27 toolbar APIs (visibility-priority, explicit overflow, pinned placement)
  stay out of scope until a narrow-window resize test shows an essential action is
  lost: #16.
