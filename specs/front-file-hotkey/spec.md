# 全局快捷键：把前台选中的文件加入架子

## 背景与目标

人已经在 Finder、VSCode 或同类窗口里选好了文件，还要再拖一次才进架子。加一条全局快捷键：按一下，选中的本地文件复制进架子（原件不动），面板打开能看见。不自动跑 Recipe。

系统没有「任意 App 的选中文件」接口，所以两条路都做：

- **A**：Finder 读选中项；其他 App 读当前打开的本地文件（窗口 `AXDocument`）。
- **B**：对前台 App 模拟 ⌘C，只接受剪贴板里的**文件**（路径 / file URL）。不是文件则丢掉这次复制，剪贴板还原，再走 A。

## 当前行为

- 进货：拖、+、搜索、面板内粘贴、抓页快捷键。
- 没有「前台选中文件」热键。Finder 里 ⌘C 再回 DropAgent 粘贴可以，但要切窗口。

## 范围

- 新全局快捷键，默认 `⌃⌥A`，设置里可改，必须带修饰键。占用时设置清单标明。
- 按键先钉死前台 App，再开面板，避免面板抢前台。
- 判定：
  1. DropAgent 自己在最前：提示去 Finder / 编辑器里选。
  2. Safari / Chrome / Edge / Brave / Arc / Firefox 在最前：提示这不是文件，用抓页快捷键。不模拟 ⌘C，不抓网页。
  3. Finder：自动化读 `selection`。空选中提示先选文件。第一次要「控制 Finder」（进程内 `AEDeterminePermissionToAutomateTarget`，不经 `osascript` 要权）。
  4. 其他 App：要辅助功能。先模拟 ⌘C；剪贴板若是存在的本地文件（可多条）就用这些；否则还原剪贴板，再读前台窗口 `AXDocument` 的本地文件。
- B 成功只认文件。文字、图、网页链接不当成这次进货；编辑器里选中的字不会变成 CLIP。
- VSCode / Cursor 侧栏多选：靠 B。当前打开的 tab：B 没拿到文件时靠 A。
- 进货走链 A：`Ingest.admit(urls:)`。复制进写入区域，不覆盖原件，不收符号链接。
- 设置快捷键多一行；「能做什么」写清这条。就绪清单加 Finder 控制权，**不**算进抓页就绪，不挡第一次拖文件。
- 菜单栏菜单加一项。页脚带上当前键。
- App 不 import Capture。四条调用链不变。

## 非目标

- 不为 VSCode / Cursor 做插件。
- 不解析编辑器画面、不点侧栏。
- 不把远程 URI（`vscode-remote:` 等）当本地文件。
- 不改抓页语义。

## 方案

内核 `DropAgentCapture.FrontFiles`：分类、Finder 脚本、模拟 ⌘C 并还原剪贴板、AX 文件。`DropAgentIngest.FrontAdmit` 给 App。壳注册第三条 Carbon 热键。

## 文件边界

- `macos/Packages/DropAgentCapture/Sources/FrontFiles.swift`
- `macos/Packages/DropAgentCapture/Sources/AccessibilityPage.swift`
- `macos/Packages/DropAgentIngest/Sources/FrontAdmit.swift`、`PageAdmit.swift`
- `macos/App`：热键、偏好、设置、就绪清单、Session、菜单、e2e
- `01-requirements.md`、`02-prototype-design.md`、`03-tech-architecture.md`、`PRODUCT.md`、`DESIGN.md`、`design/modules/app-shell.md`、`prototype/index.html`

## 验收

1. Finder 选中文件按默认键：架子出现副本，原件不动，面板打开。
2. VSCode 侧栏多选：进多条。编辑器里只选了字：进当前打开的本地文件，不进 CLIP。
3. 浏览器最前：不进文件，提示用抓页键。
4. 设置能改这条快捷键；说明与 01 / 02 一致。
5. Check 全绿；`--e2e` 能看到该快捷键文案，且能 set/reset。

## 验证

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```
