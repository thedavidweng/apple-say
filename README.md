<div align="center">
  <img src="Resources/AppIcon.png" alt="Apple Say Icon" width="128" height="128" />
  <h1>Apple Say</h1>
  <p><strong>A native macOS studio for speech synthesis, LRC, and Enhanced LRC timed text.</strong></p>

  <p>
    <a href="https://github.com/thedavidweng/apple-say/releases"><img src="https://img.shields.io/github/v/release/thedavidweng/apple-say?color=007AFF&label=Release&logo=apple" alt="GitHub Release" /></a>
    <a href="https://developer.apple.com/macos/"><img src="https://img.shields.io/badge/macOS-14.0%2B%20Sonoma-black?logo=apple" alt="macOS 14+" /></a>
    <a href="https://www.swift.org"><img src="https://img.shields.io/badge/Swift-6.4-F05138?logo=swift&logoColor=white" alt="Swift 6.4" /></a>
    <a href="#installation"><img src="https://img.shields.io/badge/Homebrew-thedavidweng%2Ftap-FBB040?logo=homebrew" alt="Homebrew Tap" /></a>
    <a href="PRIVACY.md"><img src="https://img.shields.io/badge/Privacy-100%25%20Local-success" alt="Privacy First" /></a>
  </p>

  <p>
    <a href="README.md"><strong>English</strong></a> •
    <a href="README_zh.md"><strong>简体中文</strong></a>
  </p>

  <br />
  <img src="public/screenshot.png" alt="Apple Say Main Window" width="800" />
</div>

---

**Apple Say** is a native macOS application for speech synthesis and timed-audio creation. It uses macOS system speech synthesizers and `/usr/bin/say` to write, preview, and export Plain Text, LRC, and Enhanced LRC documents.

Speech synthesis runs locally using macOS system components without external network requests or subscriptions.

---

## ✨ Features

- 📄 **Editor Workflow**: Launches directly into an editor window. Enter text and preview or export audio without having to save a file first.
- ⏱️ **Timed-Text Alignment**: Supports Plain Text, LRC (line-level timing), and Enhanced LRC (word/fragment-level timing). When timestamps are present, speech duration is measured and playback speed is adjusted to keep speech within each interval.
- 🗣️ **System & Personal Voices**: Lists voices installed on macOS with language filtering. Supports macOS **System Voice** (including Siri voices configured under Spoken Content) and authorized **Personal Voice** profiles.
- 🎛️ **Speech Inspector**: Configures speech rate (WPM), pitch, output container formats (AAC, AIFF, WAV, CAF), audio channels, sample rates, bitrates, and converter quality.
- 🎧 **Playback & Audio Export**: Preview playback with keyboard shortcuts or export audio files through the macOS save panel.
- 🔒 **Local & Offline**: Speech synthesis and audio processing run locally. No network requests, telemetry, or third-party runtime dependencies.

---

## 🚀 Installation

### Homebrew (Recommended)

Install Apple Say via the [thedavidweng/homebrew-tap](https://github.com/thedavidweng/homebrew-tap):

```bash
brew install --cask thedavidweng/tap/apple-say
```

To update in the future:

```bash
brew upgrade --cask apple-say
```

### Direct Download

1. Download the latest `Apple-Say.dmg` from the [GitHub Releases](https://github.com/thedavidweng/apple-say/releases) page.
2. Open the disk image and drag **Apple Say.app** to your `/Applications` folder.
3. Launch Apple Say from Applications or Spotlight.

> [!NOTE]
> Pre-built releases are currently ad-hoc signed. If macOS Gatekeeper displays a security notice on first launch, right-click **Apple Say.app**, select **Open**, and confirm; or run `xattr -cr "/Applications/Apple Say.app"` in Terminal.

---

## 📖 Supported Formats

Apple Say automatically identifies the document format based on its syntax:

- **Plain Text**: Standard UTF-8 plain text for continuous speech synthesis.
- **LRC**: Line-level synchronized text with line timestamps:
  ```lrc
  [00:02.00] Hello, welcome to Apple Say.
  [00:05.50] This is line-level synchronized speech.
  ```
- **Enhanced LRC**: Word- or fragment-level synchronized text with inline timestamps:
  ```lrc
  [00:01.00] <00:01.20> Precision <00:02.00> word-level <00:02.80> alignment.
  ```

If syntax errors or conflicting timestamps are detected, the editor treats the content safely as Plain Text or notifies you with a timing error.

---

## ⌨️ Keyboard Shortcuts

| Action | Shortcut |
| :--- | :--- |
| **Preview Speech** | `⌘ Return` |
| **Stop Playback** | `⌘ .` |
| **Export Audio** | `⇧ ⌘ E` |
| **Toggle Speech Inspector** | `⌥ ⌘ I` |

---

## 🛠️ Building from Source

### Prerequisites

- macOS 14.0 (Sonoma) or later
- Xcode Command Line Tools with Swift 6.0 or later

### Build Instructions

```bash
# Clone the repository
git clone https://github.com/thedavidweng/apple-say.git
cd apple-say

# Build the standalone application bundle
./scripts/build-app.sh

# Launch the built app
open "build/Apple Say.app"
```

### Running Tests

```bash
swift test
```

### Packaging Release Assets

```bash
./scripts/package-release.sh
```

Artifacts (`Apple-Say.dmg`, `Apple-Say.zip`, and `checksums.txt`) will be generated inside the `dist/` directory.

---

## 🛡️ Privacy & Permissions

Apple Say does not collect, store, transmit, or share any personal data.

- **System Speech**: Speech rendering is handled locally via native macOS APIs.
- **Personal Voice**: When selecting a macOS Personal Voice, macOS will prompt you for authorization. Apple Say uses this permission exclusively to preview and export text you explicitly choose.

For more details, see [PRIVACY.md](PRIVACY.md).

---

## 📄 License & Contributing

- Project specifications and terminology are documented in [CONTEXT.md](CONTEXT.md).
- Contribution guidelines and pre-commit checks are documented in [CONTRIBUTING.md](CONTRIBUTING.md).
- Bug reports, feature suggestions, and contributions are welcome via [GitHub Issues](https://github.com/thedavidweng/apple-say/issues).
