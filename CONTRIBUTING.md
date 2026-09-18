<div align="center">
  <img src="Resources/AppIcon.webp" alt="Apple Say Icon" width="96" height="96" />
  <h2>Contributing to Apple Say</h2>
  <p><strong>Code contribution guidelines, commit standards, and pre-commit checks.</strong></p>
</div>

---

## 🛠️ Pre-Commit Verification

Before committing and opening a Pull Request, all three checks must pass locally:

```bash
# 1. Lint (0 errors, 0 warnings, max 160 chars/line)
swiftlint lint --strict

# 2. Tests (Swift 6 strict concurrency, warnings as errors)
swift test -Xswiftc -warnings-as-errors

# 3. App bundle build & signing (requires Xcode 26+ for actool)
./scripts/build-app.sh
```

---

## 📝 Conventional Commits

Apple Say uses [Release Please](https://github.com/googleapis/release-please) for automated semantic versioning and changelogs. Commits must follow [Conventional Commits v1.0.0](https://www.conventionalcommits.org/):

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types

| Type | Release Action | Purpose |
| :--- | :--- | :--- |
| `feat` | **Minor** release (e.g. `0.2.0`) | New user-facing feature |
| `fix` | **Patch** release (e.g. `0.1.1`) | Bug fix |
| `perf` | **Patch** release | Performance improvement |
| `docs` | None / Patch | Documentation changes |
| `refactor` | None | Code refactoring without bug fix or feature |
| `test` | None | Adding or correcting tests |
| `build` | None | Build system and dependencies |
| `ci` | None | CI configuration and workflows |
| `chore` | None | Internal housekeeping and tool configs |

### Breaking Changes

Append `!` after type/scope or include `BREAKING CHANGE:` in the commit body:

```bash
git commit -m "feat(core)!: redesign SpeechController boundary interface"
```

---

## 🎨 Architectural Principles

1. **Native GUI for `say`**: Direct interface to macOS system speech; no private framework hacks.
2. **First-Class i18n**: Never hardcode UI strings; route text through `AppStrings.text(english, simplifiedChinese)`.
3. **Apple HIG Alignment**: Rely on system semantic colors and native controls for consistent hierarchy.
