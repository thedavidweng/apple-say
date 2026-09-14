# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.1.0](https://github.com/thedavidweng/apple-say/compare/v1.0.0...v1.1.0) (2026-09-14)


### ✨ Features

* **editor:** add localized empty document prompt ([0d02ac4](https://github.com/thedavidweng/apple-say/commit/0d02ac4671fb7a6898815ff682e6f04603777b0c))
* **ui:** adopt Liquid Glass and layered app icon ([75ffec2](https://github.com/thedavidweng/apple-say/commit/75ffec2f99a87a688d5954fb788b1417a66a54af))
* **voice:** support System Voice, instant launch, and refined UI controls ([20590ec](https://github.com/thedavidweng/apple-say/commit/20590ec135d4366e948e90ec53ed4a019a725cee))


### 🐛 Bug Fixes

* **icon:** remove decorative background arcs ([6bbfb7e](https://github.com/thedavidweng/apple-say/commit/6bbfb7e5acbbd626c2c4b2dd6c10d8953148fb53))
* **lint:** remove force casts from text editor ([18a13f4](https://github.com/thedavidweng/apple-say/commit/18a13f4a34f28266fe967f56fc5dc343c6871e1f))
* **release:** refresh pending release metadata ([08ccd50](https://github.com/thedavidweng/apple-say/commit/08ccd50f41df201e4e02862657d22f16d55680a3))
* **ui:** align About panel with macOS apps ([21f6221](https://github.com/thedavidweng/apple-say/commit/21f6221643cdc90ea49db3b90db00688e084b2d5))
* **ui:** align and simplify voice quality guide ([189eeb9](https://github.com/thedavidweng/apple-say/commit/189eeb96964346d79f50b6ed6cfa0fd86edd8640))
* **ui:** refine native macOS editor layout ([e3d701d](https://github.com/thedavidweng/apple-say/commit/e3d701d29b866e71fd4f7ad4a4a0f1d66c6e8f56))


### 📝 Documentation

* refresh README screenshot ([097a910](https://github.com/thedavidweng/apple-say/commit/097a910f5e00e1a76f1046aaf526b11ac73f8276))
* remove em dashes and refine readme copy ([b9e3d13](https://github.com/thedavidweng/apple-say/commit/b9e3d13c5d4861cb9413dfe05edb780af840e5c9))
* streamline CONTRIBUTING guide to English-only ([17dfcd0](https://github.com/thedavidweng/apple-say/commit/17dfcd04a7832dfce1e2232d72b1fc28510c8f08))

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
