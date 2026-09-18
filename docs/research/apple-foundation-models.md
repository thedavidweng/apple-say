# Apple Foundation Models integration research

Research date: 2026-09-17. Sources are Apple documentation, Apple developer
sessions, and the public interfaces in the installed Xcode 27 SDK.

## Recommendation

Use the native Swift `FoundationModels` framework in Apple Say. Do not launch
`/usr/bin/fm` from the app.

- Keep Apple Say's macOS 14 minimum, and compile the intelligence code behind
  `if #available(macOS 26.0, *)`. The feature is absent on macOS 14 and 15.
- Use `SystemLanguageModel.default` and its `availability` value to decide
  whether to expose an intelligence action. The API distinguishes an ineligible
  device, Apple Intelligence being disabled, and a model that is not ready.
- Grammar refinement is a good fit for the on-device model. Timeline repair can
  use guided generation to produce a typed proposal, but the existing
  deterministic timed-text parser and timing validation must remain the final
  authority.
- Foundation Models can be prompted to translate between supported languages,
  but Apple explicitly says the dedicated Translation framework has broader
  language support. If the product requirement is specifically “translated by
  Apple Foundation Models,” treat translation as a reviewed generative edit and
  gate both source and target languages with `supportsLocale(_:)`. If translation
  coverage and fidelity are the priority, use Apple's on-device Translation
  framework instead.

## OS and distribution boundary

The public Swift framework was introduced with the 2025 OS release and is
available on **macOS 26 or later**, not macOS 15. The local Xcode 27 SDK declares
`SystemLanguageModel`, `LanguageModelSession`, `@Generable`, `@Guide`, streaming,
and `Tool` with `@available(macOS 26.0, *)`. Apple introduced the framework at
WWDC25 as a direct Swift API to the on-device model on macOS, iOS, iPadOS, and
visionOS. [Meet the Foundation Models framework (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/286/)

Apple Say currently declares `.macOS(.v14)` in `Package.swift`. A guarded native
integration therefore preserves current OS support; raising the entire app's
deployment target is unnecessary.

The model also requires an Apple Intelligence-capable Mac. Apple's current
requirements specify Apple silicon, Apple Intelligence enabled, sufficient
storage, a supported region, and device and Siri languages set to the same
supported language. Models download after Apple Intelligence is enabled and may
temporarily be unavailable during that process. [How to get Apple Intelligence](https://support.apple.com/121115)

Language and model support evolves with OS updates. The app must query the
runtime rather than hard-code a language list. Apple's current framework exposes
`supportedLanguages` and `supportsLocale(_:)`; the latter accounts for close
locale fallbacks. [Supporting languages and locales with Foundation Models](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models)

## Availability and lifecycle

The app-level readiness check is:

```swift
switch SystemLanguageModel.default.availability {
case .available:
    // Offer the relevant intelligence action.
case .unavailable(.deviceNotEligible):
    // This Mac cannot run the system model.
case .unavailable(.appleIntelligenceNotEnabled):
    // Apple Intelligence is off.
case .unavailable(.modelNotReady):
    // The model is downloading or temporarily not ready.
}
```

This is the supported application API and is more informative than shelling out
to `fm available`. [SystemLanguageModel](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel),
[Adding intelligent app features with generative models](https://developer.apple.com/documentation/foundationmodels/adding-intelligent-app-features-with-generative-models)

The framework can also throw `unsupportedLanguageOrLocale` after inspecting the
actual prompt. Preflight source and requested target locales, then still handle
that runtime error because mixed-language input can differ from an app or voice
locale. Apple's language guidance recommends explicit locale instructions and an
explicit output language; otherwise the model may answer in any language present
in its inputs. [Supporting languages and locales with Foundation Models](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models)

## Relevant framework capabilities

### Guided generation

`@Generable` describes Swift output types and `@Guide` supplies semantic and
programmatic constraints. Apple describes guided generation as constrained
decoding that guarantees the generated structure, avoiding fragile JSON or CSV
parsing. This is the right primitive for a timeline-repair proposal such as a
list of segment identifiers, proposed text/timestamps, and explanations.
Structural validity does **not** prove semantic or timing correctness, so the
proposal must pass Apple Say's normal parser and timing rules before it can be
offered to the user. [Meet the Foundation Models framework (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/286/),
[Deep dive into the Foundation Models framework (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/301/)

### Streaming

`LanguageModelSession.streamResponse` streams snapshots rather than raw token
deltas. For structured output, the generated `PartiallyGenerated` type exposes a
progressively filled value that maps naturally to SwiftUI. Streaming is useful
for progress or a preview, but Apple Say should apply grammar/timeline changes as
one reviewed edit rather than continuously mutating the document. [Meet the
Foundation Models framework (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/286/)

### Tool calling

Types conforming to `Tool` let the model call app-defined async Swift code, with
guided generation constraining tool names and arguments. The framework executes
the tool and adds its result to the session transcript. Apple Say probably does
not need a tool for the first implementation: supplying parsed document context
and asking for typed output is smaller and more predictable. A future narrowly
scoped read-only tool could expose deterministic duration/timing calculations;
the model should never receive a tool that directly mutates the document.
[Meet the Foundation Models framework (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/286/)

### Model limits

Apple positions the roughly three-billion-parameter on-device model for focused
tasks such as summarization, extraction, classification, text understanding, and
editing—not world knowledge or advanced reasoning—and recommends decomposing
complex tasks. Grammar refinement fits directly. Timeline repair should therefore
be a small, well-specified transformation with deterministic validation rather
than an open-ended request to “fix everything.” Outputs are probabilistic and may
change when the OS updates its model, even with greedy sampling, so prompts need
versioned evaluation fixtures. [Generating content and performing tasks with
Foundation Models](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models),
[Deep dive into the Foundation Models framework (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/301/),
[Foundation Models updates](https://developer.apple.com/documentation/updates/foundationmodels)

## Translation assessment

The system language model is multilingual and can use different supported
languages for instructions, prompts, and output. Apple documents explicitly
setting the requested output language in session instructions, so an AFM-backed
translation feature is technically supported. Both the detected input language
and requested target language need to be model-supported. [Supporting languages
and locales with Foundation Models](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models)

It is not, however, Apple's broadest translation API. In a WWDC26 Machine
Learning & AI lab, Apple said that Foundation Models can translate but the
Translation APIs support more languages. The Translation framework is purpose
built, on-device, and available from macOS 15; it manages language-model download
permission and exposes source/target translation sessions. [Machine Learning &
AI Group Lab (WWDC26)](https://developer.apple.com/videos/play/wwdc2026/8016/),
[TranslationSession](https://developer.apple.com/documentation/translation/translationsession),
[Translating text within your app](https://developer.apple.com/documentation/translation/translating-text-within-your-app)

Consequently:

- choose Foundation Models when the desired behavior is a generative,
  context-aware rewrite into another supported language and the user reviews the
  result;
- choose Translation when the desired behavior is faithful translation with the
  widest Apple-supported language coverage;
- do not silently substitute one engine for the other. Their availability,
  language coverage, and output semantics differ.

For LRC and Enhanced LRC, never ask the model to regenerate markup as free-form
text. Parse first, translate only the spoken text fields, preserve segment IDs and
timestamps in code, and reconstruct the document deterministically. Guided
generation can bind translated strings to stable segment IDs.

## The `fm` command-line tool

`fm` is official, but it is **new in macOS 27**, not macOS 15. Apple describes it
as a preinstalled terminal tool for prompt experiments, shell automation, chat,
structured output, and model availability checks. [Build AI-powered scripts with
the fm CLI and Python SDK (WWDC26)](https://developer.apple.com/videos/play/wwdc2026/334/)

The macOS 27 `fm(1)` manual installed on the research machine documents this
first-run workflow:

- `sudo fm license` displays and records acceptance of the Apple Foundation
  Models CLI Legal Notice & Terms for every user on the machine;
- the user answers `yes` or `y`; other input exits with status 69;
- `fm license --status` checks acceptance, and `fm license --show` prints the
  terms;
- `fm available` checks model availability.

Those terms gate the **CLI**, not the Swift framework. Requiring an app user to
approve a machine-wide license with administrator privileges is inappropriate
for a normal application feature. It also excludes macOS 26, where the public
Swift framework already works.

Launching `fm` through `Process` is also a poor distribution boundary. Apple
documents that a child process of a sandboxed app inherits the parent's sandbox,
while the installed `/usr/bin/fm` is Apple-signed with its own private model
entitlement and is not sandboxed. Depending on that executable's private signing
configuration, CLI output contract, and global license state is less stable than
using the public in-process API. [Process](https://developer.apple.com/documentation/foundation/process),
[Configuring the macOS App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox)

Use `fm` only during prompt prototyping and evaluation. Ship the equivalent Swift
prompt, `LanguageModelSession`, `@Generable` types, and availability checks in the
app. This is also the conservative licensing boundary: Apple demonstrates `fm`
in user-authored shell automation, but neither its public documentation nor the
CLI legal notice expressly establishes it as an embedding interface for shipped
third-party applications.

## Sandbox, signing, and privacy

Apple's documentation lists no special entitlement for the on-device
`SystemLanguageModel`; it is exposed through the public framework. This differs
from the macOS 27 `PrivateCloudComputeLanguageModel`, whose documentation lists a
dedicated Private Cloud Compute entitlement. Apple Say does not need PCC for the
requested features. [Foundation Models](https://developer.apple.com/documentation/foundationmodels/)

Mac App Store distribution requires App Sandbox. The current repository's
release script ad-hoc signs the app and does not add sandbox entitlements, which
is a separate pre-existing distribution gap to address before App Store
submission. Direct Foundation Models use does not require network or broad file
access; document data can be passed in memory. [Preparing your app for
distribution](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution),
[Configuring the macOS App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox)

Apple states that on-device model input and output stay on-device, the model can
work offline, and it adds nothing to the app binary. This preserves Apple Say's
local-processing posture. The UI should nevertheless identify generative edits,
let the user review them, and never overwrite the document without an explicit
accept action. [Meet the Foundation Models framework (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/286/)

The existing “Data Not Collected” privacy position can remain accurate for an
on-device-only implementation that adds no analytics, logging upload, external
tools, or PCC. Avoid persisting prompts/transcripts unless they are deliberately
part of the user's document workflow.

## Implementation shape for Apple Say

1. Add a small macOS-26-only model service around `SystemLanguageModel.default`
   and `LanguageModelSession`; keep Foundation Models out of the document and
   speech-domain types.
2. Derive feature visibility from document state plus model availability:
   grammar repair for nonempty editable text, timeline repair only after the
   deterministic parser identifies a concrete timed-text issue, and translation
   only when detected source and selected voice language differ and both are
   supported.
3. Return proposals, never direct mutations. Present a preview/diff and apply the
   accepted result as one undoable document edit.
4. Preserve timed-text structure in code. Ask the model only for typed text or
   repair proposals keyed by existing segment identity, then run the canonical
   parser and timing validator before enabling Apply.
5. Add prompt evaluations for grammar preservation, timestamp invariants,
   unsupported/mixed languages, sensitive-content refusals, long documents, and
   each supported OS/model version. Apple explicitly advises retesting prompts as
   OS model versions change. [Foundation Models updates](https://developer.apple.com/documentation/updates/foundationmodels)
