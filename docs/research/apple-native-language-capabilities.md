# Apple-native language capabilities for Apple Say

Research date: 2026-09-17. This report is based on Apple documentation,
Apple WWDC sessions, and the public interfaces in the installed Xcode 27 macOS
SDK. It maps integration seams only; no application code was changed.

## Decision

Use the narrowest first-party capability for each job:

| Job | Native capability | Minimum macOS | Product role |
| --- | --- | --- | --- |
| Detect the Document's likely language | `NaturalLanguage.NLLanguageRecognizer` | 10.14 | Decide whether a translation suggestion is relevant; never modify text |
| Translate into the selected Voice Language | `Translation` / `TranslationSession` | 15.0 | Purpose-built, on-device translation and model-download UX |
| User-driven proofreading and rewriting | AppKit Writing Tools on `NSTextView` | 15.0 | Native Apple Intelligence UI for proofread, rewrite, tone, concise, summary, and transformations |
| App-defined, programmatic polish proposal | `FoundationModels.LanguageModelSession` | 26.0 | Only when Apple Say needs its own prompt, result, validation, and review UI |
| App-defined Timed Text repair proposal | Foundation Models plus Apple Say's deterministic parser/validator | 26.0 | Structured proposal only; code remains authoritative |
| Conventional spelling/grammar underlines | `NSTextView` / `NSSpellChecker` | Existing deployment target | Optional non-generative editing aid, independent of Apple Intelligence |

This avoids using the general system language model for translation and avoids
reimplementing the standard Writing Tools experience. It also preserves Apple
Say's macOS 14 core feature set: each addition is availability-gated rather than
raising the package deployment target.

## 1. Translation: purpose-built and on-device

`TranslationSession`, `LanguageAvailability`, their string and batch methods,
and the SwiftUI `translationTask` modifiers are public on **macOS 15.0+**. Apple
states that `TranslationSession` translations are processed on the user's
device. Apple may collect usage/performance metadata such as the app bundle ID
and source/target languages, but not the original or translated content.
[TranslationSession](https://developer.apple.com/documentation/translation/translationsession)

### Availability and language detection

Use `LanguageAvailability` before showing an Apple Say translation action:

- `status(from:to:)` checks a known language pair.
- `status(for:to:)` identifies the source from sample text and checks the pair.
- `.installed` means the pair is supported and ready.
- `.supported` means the pair is supported but not yet usable until its models
  are downloaded.
- `.unsupported` means do not offer the action.

`supportedLanguages` is asynchronous and must be queried at runtime; do not
hard-code Apple's evolving language list. A language must be installed before
translation can run. [LanguageAvailability](https://developer.apple.com/documentation/translation/languageavailability),
[LanguageAvailability.Status](https://developer.apple.com/documentation/translation/languageavailability/status)

For the contextual “Document language differs from Voice Language” signal, use
`NLLanguageRecognizer` to obtain hypotheses and probabilities, and compare the
top language code with the selected Voice's `Voice.language` through
`Locale.Language`. Apple's SDK warns that language identification is unreliable
for short or ambiguous input, especially below roughly 30 characters. Therefore
the suggestion should remain absent until there is enough prose and one
hypothesis is convincingly dominant. This confidence threshold is a product
heuristic, not an Apple API guarantee. `LanguageAvailability.status(for:to:)`
must still be the final support check.
[Identifying the language in text](https://developer.apple.com/documentation/naturallanguage/identifying-the-language-in-text)

### Download and permission UX

On macOS 15, the supported way to obtain a `TranslationSession` that may request
missing language downloads is SwiftUI's:

```swift
.translationTask(configuration) { session in
    let responses = try await session.translations(from: requests)
}
```

The session is tied to the view that owns the modifier. Do not store it in a
persistent service or model. Store `TranslationSession.Configuration` in view
state and call `invalidate()` to run a new request. The framework asks the user
for download permission only when necessary, presents download progress, shares
downloaded models with other apps, and can continue downloads after the sheet or
app is dismissed. `prepareTranslation()` requests download approval in advance.
[Meet the Translation API (WWDC24)](https://developer.apple.com/videos/play/wwdc2024/10117/),
[Translating text within your app](https://developer.apple.com/documentation/translation/translating-text-within-your-app)

Xcode 27 also exposes `TranslationSession(installedSource:target:)` on **macOS
26.0+** for non-UI contexts. It only works with already-installed languages and
cannot obtain download consent; missing models cause an error. The SwiftUI-owned
session remains the correct main path because Apple Say must support first-use
downloads. `canRequestDownloads` and async `isReady` are also macOS 26+.
[init(installedSource:target:)](https://developer.apple.com/documentation/translation/translationsession/init%28installedsource%3Atarget%3A%29),
[isReady](https://developer.apple.com/documentation/translation/translationsession/isready)

`translationPresentation` is available on macOS 14.4 and offers a complete
system translation popover with an optional replacement closure. It is useful
for a generic “Translate…” command, but it gives the person the system
experience rather than Apple Say's required automatic target of the selected
Voice Language. Use `TranslationSession` for the contextual feature.

### Preserving Timed Text

For Plain Text, translate the selected range or whole Document. For LRC and
Enhanced LRC, parse first and send only each Segment's spoken content as a batch
of `TranslationSession.Request` values. Use `clientIdentifier` to carry a stable
Segment identity, then deterministically reassemble the Document with all
Timestamp syntax unchanged. Apple recommends batch APIs for multiple strings of
the same language and guarantees that `translations(from:)` returns results in
request order. [Translating text within your app](https://developer.apple.com/documentation/translation/translating-text-within-your-app)

On macOS 26.4, Translation adds `AttributedString` translation and the
`translation.skipsTranslation` attribute. Those APIs can preserve formatting
and application metadata, but they do not replace the parser boundary: the
single implementation that parses/reassembles Timed Text is smaller and works
on every supported Translation release.

## 2. Writing Tools: the native Apple Intelligence proofreading UI

Yes—Apple provides a dedicated integration surface for Apple Intelligence
Writing Tools. It proofreads, rewrites, summarizes, changes tone, and transforms
text through system UI. `NSTextView` and `NSTextField` automatically support it.
On macOS, the system exposes Writing Tools through the context menu, Edit menu,
and the selection affordance when available.
[Writing Tools](https://developer.apple.com/documentation/appkit/writing-tools),
[Get started with Writing Tools (WWDC24)](https://developer.apple.com/videos/play/wwdc2024/10168/)

Apple Say already uses an editable AppKit `NSTextView` created by
`NSTextView.scrollableTextView()` inside `DocumentTextEditor`. On macOS Ventura
and later, standard text controls use TextKit 2 by default. The current code does
not access the legacy `layoutManager` property, so it should receive the full
inline Writing Tools experience rather than the limited panel caused by TextKit
1 compatibility mode. This should be verified on-device by checking that
`textView.textLayoutManager` remains non-`nil`.
[What's new in TextKit and text views (WWDC22)](https://developer.apple.com/videos/play/wwdc2022/10090/)

Implementation-critical AppKit APIs from the Xcode 27 SDK are:

- **macOS 15.0:** `NSTextView.writingToolsBehavior`,
  `allowedWritingToolsResultOptions`, `isWritingToolsActive`, the
  `textViewWritingToolsWillBegin` / `textViewWritingToolsDidEnd` delegate
  callbacks, and `textView(_:writingToolsIgnoredRangesInEnclosingRange:)`.
- **macOS 15.2:** `NSResponder.showWritingTools(_:)`,
  `NSMenuItem.writingToolsItems`, `NSMenu.automaticallyInsertsWritingToolsItems`,
  `NSToolbarItem.Identifier.writingToolsItemIdentifier`, and
  `NSWritingToolsExclusionAttributeName`.
- **macOS 15.4:** SwiftUI's `writingToolsAffordanceVisibility(_:)`.

Keep `writingToolsBehavior = .default` (or `.complete` only if testing proves a
need) and set `allowedWritingToolsResultOptions = .plainText`, because a Document
is stored as plain text. Apple says `.default` chooses the best available
experience. The limited experience keeps proposed changes in a panel; the
complete experience applies temporary changes inline while the user reviews
them. [Customizing Writing Tools behavior for AppKit views](https://developer.apple.com/documentation/appkit/customizing-writing-tools-behavior-for-system-views)

For LRC and Enhanced LRC, implement
`textView(_:writingToolsIgnoredRangesInEnclosingRange:)` and return ranges for
line and inline Timestamp markup. This is the standard API specifically intended
to prevent Writing Tools from modifying code-like or otherwise protected
ranges. It lets Writing Tools polish spoken content without corrupting timing.

Writing Tools may mutate the text storage temporarily while a session is active,
and accepted operations are added to the undo stack. Apple Say's coordinator
currently forwards every `textDidChange` into SwiftUI state. It has no autosave,
so this is not presently persisted, but integration should track the will-begin
and did-end callbacks and avoid treating transient text as a final Document or
starting Preview/Export during the session.

### What Writing Tools does not expose

Writing Tools is not a headless proofreading service. Public AppKit can open the
system UI with `showWritingTools(_:)`, but it cannot programmatically choose
“Proofread,” supply a private prompt, or await a final rewritten `String`.
For a standard `NSTextView`, accepted changes arrive as ordinary text-storage
edits observable through its delegate. The lower-level
`NSWritingToolsCoordinator` can deliver proposed replacement chunks to a custom
view delegate, but Apple documents it for views that implement their own text
engine; it still represents a user-driven Writing Tools workflow and is not a
general grammar endpoint.
[Adding Writing Tools support to a custom AppKit view](https://developer.apple.com/documentation/appkit/adding-writing-tools-support-to-a-custom-appkit-view),
[replacement delegate method](https://developer.apple.com/documentation/appkit/nswritingtoolscoordinator/delegate-swift.protocol/writingtoolscoordinator%28_%3Areplace%3Ain%3Aproposedtext%3Areason%3Aanimationparameters%3Acompletion%3A%29)

Consequently, let system Writing Tools own normal proofreading and tone changes.
Use Foundation Models only when Apple Say needs an app-defined command and must
receive, validate, compare, or reject the generated result itself.

## 3. Foundation Models: custom programmatic transforms

The public `FoundationModels` framework starts at **macOS 26.0**. The Xcode 27
SDK exposes `SystemLanguageModel.default`, its observable `availability`,
`supportedLanguages`, `supportsLocale(_:)`, and `LanguageModelSession`.
Availability distinguishes `.deviceNotEligible`,
`.appleIntelligenceNotEnabled`, and `.modelNotReady`. These are the app APIs;
the `fm` CLI and its administrator license flow are not an application
integration boundary.
[Meet the Foundation Models framework (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/286/),
[SystemLanguageModel](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel)

Foundation Models is appropriate for:

- a custom “Polish” proposal with Apple Say-specific constraints and a diff or
  review sheet;
- structured Timed Text repair proposals using guided generation;
- transformations where the app needs the generated value before deciding
  whether to modify the Document.

It is not the best translation engine, and it should not duplicate the ordinary
Proofread/Rewrite experience already supplied by Writing Tools. Model output is
probabilistic. Preserve Timestamp syntax in code, request proposals keyed to
stable Segment identities, validate the rebuilt Document deterministically, and
apply only after user confirmation as one undoable edit. See the companion
research note [apple-foundation-models.md](./apple-foundation-models.md) for the
full framework and `fm` assessment.

## 4. Conventional system spelling and grammar

Independent of Apple Intelligence, `NSTextView` exposes
`isContinuousSpellCheckingEnabled` and, since macOS 10.5,
`isGrammarCheckingEnabled`. `NSSpellChecker` also exposes
`checkGrammar(of:startingAt:language:wrap:inSpellDocumentWithTag:details:)` and
unified `checkString` APIs. These are useful for familiar underline-and-correction
behavior on all Apple Say-supported systems; they are not generative polishing
and do not replace Writing Tools or Foundation Models.
[NSSpellChecker](https://developer.apple.com/documentation/appkit/nsspellchecker)

Do not build a second grammar-review UI around `NSSpellChecker` unless a concrete
product requirement appears. Enabling the standard text-view behavior is the
minimal native option.

## 5. Repository integration seams

The relevant existing code is concentrated in
`Sources/AppleSay/DocumentView.swift`:

1. `DocumentTextEditor.makeNSView` is the seam for plain-text Writing Tools
   configuration and standard spelling/grammar behavior.
2. `DocumentTextEditor.Coordinator` is the seam for Writing Tools lifecycle,
   ignored Timestamp ranges, selection state, and final text synchronization.
3. `DocumentView.language` is the current Voice Language filter. A translation
   target should be derived from the selected `settings.voice?.language` when a
   Voice is explicit, otherwise from the nonempty Voice Language selection.
   “All Languages” has no translation target and must not show the suggestion.
4. A `TranslationSession.Configuration?` belongs in `DocumentView` state and the
   `translationTask` modifier belongs on its stable view hierarchy. The closure
   should call a document-translation service that receives the short-lived
   session; the service must not retain it.
5. Language detection should run after a debounce on a snapshot of spoken text,
   not on Timestamp markup and not on every keystroke. Cancel stale work when
   the Document or Voice Language changes.
6. Translation and custom Foundation Model operations should return proposals.
   Applying one must go through `NSTextView`'s editing/undo path rather than
   assigning `textView.string`, because the current `updateNSView` assignment
   does not register an undoable user edit.

No Speech framework API performs language identification, translation, or
proofreading. The speech subsystem's relevant datum is the chosen Voice locale,
which is the translation target; transformation should remain outside speech
synthesis.

## Recommended visible behavior

- macOS 14: current app, optionally standard spelling/grammar checking only.
- macOS 15+: Writing Tools appears through native text selection/contextual UI.
  When confident language detection differs from an explicit Voice Language and
  `LanguageAvailability` says the pair is supported, show one contextual
  “Translate to …” action. Triggering it may produce Apple's download-consent
  sheet, then an Apple Say review before replacement.
- macOS 26+: additionally offer app-defined Foundation Models actions only where
  the system Writing Tools workflow cannot express the requirement, notably
  validated Timed Text repair or a custom constrained polish proposal.

This division keeps each feature local, native, and absent when irrelevant or
unsupported, while avoiding parallel implementations of the same system tool.
