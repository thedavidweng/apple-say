<div align="center">
  <img src="Resources/AppIcon.png" alt="Apple Say 图标" width="128" height="128" />
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
  <img src="public/screenshot.png" alt="Apple Say 主窗口界面" width="800" />
</div>

---

**Apple Say** 是一个 macOS 原生语音合成与时间轴音频制作工具。直接调用 macOS 内置的系统语音合成器与 `/usr/bin/say`，支持纯文本、LRC 与增强型 LRC 文档的编辑、实时试听与音频导出。

所有语音合成均在本地离线运行，无网络请求，无需订阅。

---

## ✨ 核心特性

- 📄 **直接编辑与试听**：启动直接进入编辑界面，无需预先保存文件即可输入文本并试听或导出。
- ⏱️ **时间轴自适应**：支持纯文本、LRC（行级时间戳）与增强型 LRC（字/词级时间戳）。系统会测量渲染时长并自适应语速，保证语音与时间戳位置匹配。
- 🗣️ **系统声音与个人声音**：识别 macOS 中已安装的所有语音并支持按语言筛选；支持 **系统声音（System Voice）**（可直接使用在辅助功能中设置的 Siri 语音），并支持经系统授权的 Apple **个人声音（Personal Voice）**。
- 🎛️ **语音检查器（Speech Inspector）**：支持调整语速与音高，选择输出格式（AAC、AIFF、WAV、CAF），并可配置声道数、采样率、比特率与转换质量。
- 🎧 **播放试听与导出**：支持通过快捷键播放试听，或通过 macOS 标准存储面板导出音频文件。
- 🔒 **本地离线**：完全在本地离线运行，无网络请求与用户行为统计，不依赖第三方运行时。

---

## 🚀 安装指南

### 通过 Homebrew 安装（推荐）

通过 [thedavidweng/homebrew-tap](https://github.com/thedavidweng/homebrew-tap) 快速安装：

```bash
brew install --cask thedavidweng/tap/apple-say
```

后续更新应用只需运行：

```bash
brew upgrade --cask apple-say
```

### 手动下载安装

1. 前往 [GitHub Releases](https://github.com/thedavidweng/apple-say/releases) 页面下载最新的 `Apple-Say.dmg`。
2. 双击打开镜像，将 **Apple Say.app** 拖拽至系统的 `应用程序`（`/Applications`）目录。
3. 从“启动台”或“访达”中直接打开应用。

> [!NOTE]
> 预编译版本当前使用临时签名（ad-hoc signed）。首次打开若系统提示未签名或安全性警告，可右键单击 **Apple Say.app** 选择 **“打开”** 并确认，或在终端中执行：
> `xattr -cr "/Applications/Apple Say.app"`

---

## 📖 支持的文档格式

Apple Say 会根据语法结构自动识别文档模式：

- **纯文本（Plain Text）**：标准 UTF-8 文本，用于连续朗读。
- **LRC**：具有行级时间戳的对齐文本：
  ```lrc
  [00:02.00] 你好，欢迎使用 Apple Say。
  [00:05.50] 这是行级对齐的时间轴语音。
  ```
- **增强型 LRC（Enhanced LRC）**：具备字级或词组级行内时间戳的对齐文本：
  ```lrc
  [00:01.00] <00:01.20> 精准 <00:02.00> 逐字 <00:02.80> 朗读对齐。
  ```

当出现语法冲突或超出时序限制时，编辑器会按纯文本处理并报告时序错误（Timing Error），不会直接修改文本或变更时间戳。

---

## ⌨️ 常用快捷键

| 操作 | 快捷键 |
| :--- | :--- |
| **试听预览（Preview）** | `⌘ Return` |
| **停止播放（Stop）** | `⌘ .` |
| **导出音频（Export Audio）** | `⇧ ⌘ E` |
| **显示/隐藏语音检视器** | `⌥ ⌘ I` |

---

## 🛠️ 从源码构建

### 环境要求

- macOS 14.0 (Sonoma) 或更高版本
- 安装了 Swift 6.0 或更高版本的 Xcode Command Line Tools

### 构建步骤

```bash
# 克隆代码仓库
git clone https://github.com/thedavidweng/apple-say.git
cd apple-say

# 编译生成独立应用包
./scripts/build-app.sh

# 打开构建好的应用
open "build/Apple Say.app"
```

### 运行单元测试

```bash
swift test
```

### 打包发布产物

```bash
./scripts/package-release.sh
```

生成的安装包（`Apple-Say.dmg`、`Apple-Say.zip` 及 `checksums.txt`）将存放于 `dist/` 目录中。

---

## 🛡️ 隐私与系统权限

Apple Say 不会收集、存储、上传或共享任何个人数据。

- **系统语音**：所有语音合成完全在你的 Mac 本地通过 macOS 系统接口完成。
- **个人声音（Personal Voice）**：选用 macOS 个人声音时，系统会弹出授权请求。Apple Say 仅将该权限用于朗读与导出你指定的内容。

详细政策参见 [PRIVACY.md](PRIVACY.md)。

---

## 📄 规范与参与贡献

- 项目领域词汇与设计规范详见 [CONTEXT.md](CONTEXT.md)。
- 代码贡献准则与提交前检查清单详见 [CONTRIBUTING.md](CONTRIBUTING.md)。
- 欢迎通过 [GitHub Issues](https://github.com/thedavidweng/apple-say/issues) 提交问题反馈、功能建议或贡献代码。
