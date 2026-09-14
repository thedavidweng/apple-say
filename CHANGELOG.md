# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0](https://github.com/thedavidweng/apple-say/releases/tag/v1.0.0) (2026-09-14)

### ✨ Features

* Native macOS studio for speech synthesis, LRC, and Enhanced LRC timed text audio production
* Pure Swift 6 language mode (`[.v6]`) and strict thread-safe audio orchestration
* System and Personal Voice synthesis support with real-time waveform and boundary tracking
* Export to compressed AAC audio and timed lyric files with precise sample placement
* Homebrew Cask distribution and automated GitHub Actions release pipeline

### 🐛 Bug Fixes

* Zero-warning build with `-warnings-as-errors` and full compliance with strict SwiftLint rules
* Reliable audio device teardown and safe fallback for personal voice authorization flows
