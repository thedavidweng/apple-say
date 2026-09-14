<div align="center">
  <img src="Resources/AppIcon.png" alt="Apple Say 图标" width="96" height="96" />
  <h2>Apple Say 贡献指南</h2>
  <p><strong>代码贡献准则、提交规范及提交前本地检查流程</strong></p>

  <p>
    <a href="CONTRIBUTING.md"><strong>English</strong></a> •
    <a href="CONTRIBUTING_zh.md"><strong>简体中文</strong></a>
  </p>
</div>

---

感谢你对 Apple Say 的关注与贡献！为了确保代码库的稳健性、可维护性并始终符合 macOS 原生应用的高标准，请在提交代码前仔细阅读以下规范。

---

## 📋 提交前快速检查清单 (Pre-Commit Checklist)

在提交代码（`git commit`）与发起 Pull Request 之前，你**必须**在本地运行并通过以下三项检查：

```bash
# 1. SwiftLint 严格代码风格检查（必须 0 violations）
swiftlint lint --strict

# 2. 自动化单元与行为测试（零警告编译模式）
swift test -Xswiftc -warnings-as-errors

# 3. 独立 App 产物构建与签名打包
./scripts/build-app.sh
```

---

## 🛠️ 检查流程分步详解

<details open>
<summary><b>1. 代码静态检查 (SwiftLint)</b></summary>
<br />

本项目遵循严格的 Swift 6 代码格式与风格规范。

- **执行命令**：
  ```bash
  swiftlint lint --strict
  ```
- **核心要求**：
  - 必须达到 `0 错误（0 errors）` 且 `0 警告（0 warnings）`。
  - 单行字符数严格限制在 **160 字符以内**。
  - 变量、方法及文件命名严格遵循既有统一命名约定。

</details>

<details open>
<summary><b>2. 自动化测试套件 (零警告模式)</b></summary>
<br />

所有单元测试、边界测试和核心业务逻辑行为测试必须全部通过。

- **执行命令**：
  ```bash
  swift test -Xswiftc -warnings-as-errors
  ```
- **核心要求**：
  - `SayBoundaryTests` 与 `SpeechBehaviorTests` 内的所有测试用例全部通过。
  - `-warnings-as-errors` 确保不会引入任何废弃 API 警告、并发安全隐患或类型推断警告。

</details>

<details open>
<summary><b>3. 应用打包构建与代码签名</b></summary>
<br />

验证 macOS 原生独立 `.app` 应用程序包能否正常编译打包与本地自签名。

- **执行命令**：
  ```bash
  ./scripts/build-app.sh
  ```
- **输出产物**：在 `build/Apple Say.app` 生成带有 ad-hoc 签名的完整应用，可直接双击运行验证实际效果。

</details>

---

## 📝 Conventional Commits 提交信息规范

Apple Say 依托 [Release Please](https://github.com/googleapis/release-please) 自动化生成版本号与更新日志（CHANGELOG）。所有提交信息必须严格遵循 [Conventional Commits v1.0.0](https://www.conventionalcommits.org/zh-hans/) 规范：

```
<type>[可选范围 scope]: <描述 description>

[可选正文 body]

[可选脚注 footer(s)]
```

### 支持的 Commit 类型

| 类型 | Release Please 触发动作 | 使用场景 |
| :--- | :--- | :--- |
| `feat` | **Minor** 次版本更新（如 `0.2.0`） | 引入用户可见的新功能或新能力 |
| `fix` | **Patch** 修订版本更新（如 `0.1.1`） | 修复缺陷或 Bug |
| `docs` | 不发布 / Patch | 仅修改文档（如 `README`、注释、贡献指南等） |
| `style` | 不发布 | 仅格式化、空格、分号等排版改动（不影响代码逻辑） |
| `refactor` | 不发布 | 代码重构（既不修复 Bug 也不新增功能） |
| `perf` | **Patch** 修订版本更新 | 提升性能或响应速度的改动 |
| `test` | 不发布 | 增加缺失测试或重构现有测试用例 |
| `build` | 不发布 | 影响构建系统或外部依赖的改动（如 SPM `Package.swift`） |
| `ci` | 不发布 | 持续集成相关的配置与脚本变更（`.github/` 目录） |
| `chore` | 不发布 | 杂务维护、构建脚本调整、日常工程杂项 |

### 提交示例

```bash
# 规范示例：
git commit -m "feat(voice): add System Voice support for Siri Natural voices"
git commit -m "fix(ui): prevent Voice dropdown overflow in All Languages mode"
git commit -m "docs: add Contributing guidelines and pre-commit checks"
git commit -m "test(boundary): add test for system voice argument construction"
git commit -m "refactor(inspector): extract VoiceQualityTheme with Apple system colors"
git commit -m "chore(release): bump version to 1.1.0"
```

### 破坏性更新 (Breaking Changes)

如果本次变更导致向后兼容性破坏，必须在类型/范围后添加 `!`，或者在提交的正文/脚注中加入 `BREAKING CHANGE:`：

```bash
git commit -m "feat(core)!: redesign SpeechController boundary interface"
```

---

## 🎨 核心设计哲学与规范

1. **坚持“GUI for `say`”定位**：
   Apple Say 是 macOS 系统内置语音能力（`say`）的原生优雅图形界面。坚决不引入容易崩溃的私有 framework hack，保持纯净与系统兼容性。
2. **严格的动态国际化支持（i18n）**：
   严禁在 UI 界面中硬编码用户可见文本。所有文本必须接入 `AppStrings.text(english, simplifiedChinese)`，确保在应用设置切换语言时界面实时无缝切换。
3. **统一遵循 Apple HIG 视觉色彩**：
   使用苹果官方系统语义色彩（`Color.purple`、`Color.orange`、`Color.green`、`Color.blue`、`Color.secondary`、`Color.pink`、`Color.indigo`）构建视觉层级，保持 macOS 平台原生质感。
