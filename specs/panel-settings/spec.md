# 顶栏设置：工作区路径、颜色、语言

## 背景与目标

右上角只有最小化和关闭。人要能自己指定「文件副本放哪」「跑完的结果放哪」，以及浅色 / 深色 / 跟随系统、中文 / 英文。这些是壳设置，不改四条调用链。

## 当前行为

- 头：字标居中，右为芯片、最小化、关闭。
- 写入默认 `Application Support/DropAgent/Inbox`，结果默认 `…/Jobs/<id>/output`。由 `DropAgentPaths` 固定，不能选。
- 面板强制 `.light`。文案只有中文。`AgentSettings` 只管终端引擎。

## 范围

- 芯片和最小化之间加齿轮（28pt 热区，`gearshape`）。点开后设置页盖住左列表 / 右 AI（终端仍留在视图树里，避免拆掉 PTY）；再点齿轮或「完成」回到架子。
- **默认工作区**
  - 写入区域 = 架子文件副本目录（现 `Inbox`）。
  - 输出结果 = Job 根目录（现 `Jobs`，结果仍在 `<id>/output/`）。
  - 选择文件夹：`NSOpenPanel` 选目录；拒绝符号链接；可新建；不自动搬已有文件、不覆盖原件。
  - 「恢复默认」清掉覆盖，回到当前 `DROPAGENT_ROOT` 下的 Inbox / Jobs。
  - `TUIInbox`、`shelf.json`、`prefs.json` 仍在 app root。
- **颜色**：浅色（默认，现有纸面）、深色（深纸面，不是系统灰）、跟随系统。立刻改面板。
- **语言**：中文（默认）、英文。立刻改面板和设置文案。Recipe 打给 Agent 的 prompt、内核 `Item.metaLine` 存盘格式不改；界面展示由 App 翻译。
- 偏好存在 `prefs.json`（与 `settings.json` 分开）。不进 `AgentSettings`。

## 非目标

- 不改四条调用链、不搬迁已有 Inbox/Jobs 里的文件。
- 不做 iCloud / 多设备。
- 不把 Recipe 中文 prompt 改成英文。
- 不改菜单栏模板图标。

## 方案

设置是面板内一页，不是新窗口。路径覆盖写在 `DropAgentPaths`；改路径后重建 `IngestService` / `JobService`。外观走 `NSAppearance` + `Palette.isDark`。语言走 `Copy.language`。

## 文件边界

- `macos/App/AppPreferences.swift`、`Copy.swift`、`SettingsPane.swift`
- `macos/App/DropAgentPaths.swift`、`Palette.swift`、`PanelRootView.swift`、`AppSession.swift`、`AppDelegate.swift`
- `macos/App/HotKeyCenter.swift`、`AppE2E.swift`
- `02-prototype-design.md`、`DESIGN.md`、`PRODUCT.md`

## 验收

1. 齿轮在最小化左侧；点开见到工作区 / Runtime / 颜色 / 语言。
2. 选写入文件夹后，新拖入的文件副本落在该目录；选输出文件夹后，新 Recipe 的 `Jobs/<id>` 落在该目录。恢复默认回到 app root 下 Inbox / Jobs。
3. 浅色 / 深色 / 跟随系统立刻改面板纸面；默认浅色。
4. 中文 / 英文立刻改设置页和面板主文案；默认中文。
5. 符号链接目录拒收。已在架子上的条目不搬家。
6. Check 全绿；`--e2e` 含设置页快照和路径 / 语言 / 外观断言。

## 验证

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```
