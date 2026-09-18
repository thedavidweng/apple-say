<div align="center">
  <img src="Resources/AppIcon.webp" alt="Apple Say 图标" width="128" height="128" />
  <h1>Apple Say</h1>
  <p><strong>基于 macOS 原生语音引擎的文本朗读、LRC 与增强型 LRC 时间轴音频工作台</strong></p>

  <p>
    <a href="https://github.com/thedavidweng/apple-say/releases"><img src="https://img.shields.io/github/v/release/thedavidweng/apple-say?color=007AFF&label=%E5%8F%91%E8%A1%8C%E7%89%88%E6%9C%AC&logo=apple" alt="GitHub 发行版本" /></a>
    <a href="https://developer.apple.com/macos/"><img src="https://img.shields.io/badge/macOS-14.0%2B%20Sonoma-black?logo=apple" alt="macOS 14+" /></a>
    <a href="https://www.swift.org"><img src="https://img.shields.io/badge/Swift-6.4-F05138?logo=swift&logoColor=white" alt="Swift 6.4" /></a>
    <a href="#安装指南"><img src="https://img.shields.io/badge/Homebrew-thedavidweng%2Ftap-FBB040?logo=homebrew" alt="Homebrew Tap" /></a>
    <a href="PRIVACY.md"><img src="https://img.shields.io/badge/%E9%9A%90%E7%A7%81-100%25%20%E6%9C%AC%E5%9C%B0%E7%A6%BB%E7%BA%BF-success" alt="隐私保护" /></a>
  </p>

  <p>
    <a href="README.md"><strong>English</strong></a> •
    <a href="README_zh.md"><strong>简体中文</strong></a>
  </p>

  <br />
  <img src="public/screenshot.webp" alt="Apple Say 主窗口界面" width="800" />
</div>

---

**Apple Say** 是专为 macOS 打造的原生语音合成与时间轴音频工具。基于系统内置语音引擎与 `/usr/bin/say`，支持纯文本、LRC 及增强型 LRC 的编辑、实时试听与音频导出——完全本地离线，无网络请求，无需订阅。

---

## ✨ 核心特性

- 📄 **即开即写**：启动即进入编辑态，免存盘直接试听与导出。
- ⏱️ **自适应对齐**：支持纯文本、LRC（行级）与增强型 LRC（字词级），按时间戳自适应调节语速。
- 🗣️ **系统与个人声音**：支持已安装系统语音（含辅助功能 Siri 语音）及经授权的 Apple 个人声音（Personal Voice），支持按语言筛选。
- 🎛️ **语音检查器**：精细调节语速与音高，支持多种容器格式（AAC、AIFF、WAV、CAF）以及声道、采样率、比特率配置。
- 🎧 **快捷试听与导出**：键盘快捷键即时试听，原生存储面板一键导出。
- 🔒 **本地离线隐私**：完全在本地运行。零埋点、零网络通信、零第三方运行时依赖。

---

## 🚀 安装指南

### 通过 Homebrew 安装（推荐）

```bash
brew install --cask thedavidweng/tap/apple-say
```

后续更新：

```bash
brew upgrade --cask apple-say
```

### 手动下载

1. 前往 [GitHub Releases](https://github.com/thedavidweng/apple-say/releases) 下载 `Apple-Say.dmg`。
2. 将 **Apple Say.app** 拖拽至 `/Applications`（应用程序）目录。
3. 从启动台或聚焦搜索打开应用。

> [!NOTE]
> 预编译版本采用临时签名（ad-hoc signed）。首次打开若遇 Gatekeeper 安全提示，右键 **Apple Say.app** 选择 **“打开”**，或在终端执行：
> `xattr -cr "/Applications/Apple Say.app"`

---

## 📖 支持的文档格式

根据语法结构自动识别文档模式：

- **纯文本（Plain Text）**：连续文本朗读，无时间戳。
- **LRC**：行级时间戳对齐：
  ```lrc
  [00:02.00] 你好，欢迎使用 Apple Say。
  [00:05.50] 这是行级对齐的时间轴语音。
  ```
- **增强型 LRC（Enhanced LRC）**：字词级行内时间戳对齐：
  ```lrc
  [00:01.00] <00:01.20> 精准 <00:02.00> 逐字 <00:02.80> 朗读对齐。
  ```

若存在语法冲突或时序溢出，安全降级为纯文本或报告时序错误（Timing Error），绝不篡改原始内容与时间戳。

---

## ⌨️ 常用快捷键

| 操作 | 快捷键 |
| :--- | :--- |
| **试听预览（Preview）** | `⌘ Return` |
| **停止播放（Stop）** | `⌘ .` |
| **导出音频（Export Audio）** | `⇧ ⌘ E` |
| **显示/隐藏语音检查器** | `⌥ ⌘ I` |

---

## 🛠️ 从源码构建

### 环境要求

- macOS 14.0+
- Xcode 26+（含 Swift 6 工具链与 Icon Composer）

### 编译与运行

```bash
git clone https://github.com/thedavidweng/apple-say.git
cd apple-say

# 编译独立应用包
./scripts/build-app.sh

# 打开应用
open "build/Apple Say.app"
```

### 测试与打包

```bash
# 运行单元测试
swift test

# 打包发布产物至 dist/
./scripts/package-release.sh
```

---

## 🛡️ 隐私与系统权限

Apple Say 绝不收集、存储、上传或共享任何个人数据。

- **系统语音**：完全调用 macOS 原生系统接口在本地完成合成。
- **个人声音（Personal Voice）**：使用 macOS 原生授权弹窗，仅用于用户明确指定的试听与导出。

详细说明参见 [PRIVACY.md](PRIVACY.md)。

---

## 📄 文档与参与贡献

- 领域术语与设计规范：[CONTEXT.md](CONTEXT.md)
- 贡献指南与提交前检查：[CONTRIBUTING.md](CONTRIBUTING.md)
- 问题反馈与功能建议：[GitHub Issues](https://github.com/thedavidweng/apple-say/issues)
