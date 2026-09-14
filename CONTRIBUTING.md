<div align="center">
  <img src="Resources/AppIcon.png" alt="Apple Say Icon" width="96" height="96" />
  <h2>Contributing to Apple Say</h2>
  <p><strong>Guidelines for code contributions, commit conventions, and pre-commit verifications.</strong></p>
</div>

---

Thank you for contributing to Apple Say! To keep our codebase robust, maintainable, and aligned with macOS native standards, please follow these guidelines.

---

## 📋 Quick Checklist Before Pushing

Before committing and opening a Pull Request, you **MUST** run and pass the following three checks locally:

```bash
# 1. SwiftLint strict check (0 violations required)
swiftlint lint --strict

# 2. Test suite with zero-warnings enforcement
swift test -Xswiftc -warnings-as-errors

# 3. Application bundle build & signing
./scripts/build-app.sh
```

---

## 🛠️ Step-by-Step Verification

<details open>
<summary><b>1. Code Linting (SwiftLint)</b></summary>
<br />

We enforce strict SwiftLint rules matching modern Swift 6 guidelines.

- **Command**:
  ```bash
  swiftlint lint --strict
  ```
- **Requirements**:
  - `0 errors` and `0 warnings`.
  - Max line length is **160 characters**.
  - Respect existing naming conventions and file headers.

</details>

<details open>
<summary><b>2. Automated Tests (Zero Warnings)</b></summary>
<br />

All unit, boundary, and behavioral test suites must pass cleanly.

- **Command**:
  ```bash
  swift test -Xswiftc -warnings-as-errors
  ```
- **Requirements**:
  - All tests in `SayBoundaryTests` and `SpeechBehaviorTests` must pass.
  - `-warnings-as-errors` ensures no deprecation warnings or concurrency warnings are introduced.

</details>

<details open>
<summary><b>3. App Bundle Build & Code Signing</b></summary>
<br />

Ensure that the standalone macOS `.app` bundle builds, packages, and signs properly.

- **Command**:
  ```bash
  ./scripts/build-app.sh
  ```
- **Output**: Produces `build/Apple Say.app` with ad-hoc signature applied.

</details>

---

## 📝 Conventional Commits Specification

Apple Say uses [Release Please](https://github.com/googleapis/release-please) to automate semantic versioning and changelog generation. All commit messages must follow the [Conventional Commits v1.0.0](https://www.conventionalcommits.org/) specification:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Supported Commit Types

| Type | Release Please Action | When to Use |
| :--- | :--- | :--- |
| `feat` | **Minor** release (e.g. `0.2.0`) | A new user-facing feature or capability |
| `fix` | **Patch** release (e.g. `0.1.1`) | A bug fix |
| `docs` | No release / Patch | Documentation changes only (`README`, comments, guides) |
| `style` | No release | Formatting, missing semi-colons, whitespace (no code change) |
| `refactor` | No release | Code change that neither fixes a bug nor adds a feature |
| `perf` | **Patch** release | A code change that improves performance |
| `test` | No release | Adding missing tests or correcting existing tests |
| `build` | No release | Changes to build tools, dependencies (e.g. SPM `Package.swift`) |
| `ci` | No release | Changes to CI configuration files and scripts (`.github/`) |
| `chore` | No release | Maintenance tasks, internal housekeeping, tool configs |

### Commit Message Examples

```bash
# Good examples:
git commit -m "feat(voice): add System Voice support for Siri Natural voices"
git commit -m "fix(ui): prevent Voice dropdown overflow in All Languages mode"
git commit -m "docs: update README with hero screenshot and feature guide"
git commit -m "test(boundary): add test for system voice argument construction"
git commit -m "refactor(inspector): extract VoiceQualityTheme with Apple system colors"
git commit -m "chore(release): bump version to 1.1.0"
```

### Breaking Changes

If a change introduces backwards-incompatible API or behavioral changes, append a `!` after the type/scope or add `BREAKING CHANGE:` in the commit body/footer:

```bash
git commit -m "feat(core)!: redesign SpeechController boundary interface"
```

---

## 🎨 Architectural Principles

1. **GUI for `say`**:
   Apple Say is designed as an elegant native interface for macOS's built-in speech engine. We avoid private framework hacks and maintain full compatibility with Apple's standard toolchain.
2. **First-Class Internationalization (i18n)**:
   Never hardcode user-facing strings. Always route UI text through `AppStrings.text(english, simplifiedChinese)` so the interface adapts reactively to the user's language settings.
3. **Apple HIG Alignment**:
   Use system semantic colors (`Color.purple`, `Color.orange`, `Color.green`, `Color.blue`, `Color.secondary`, `Color.pink`, `Color.indigo`) to represent tiers and states consistently.
