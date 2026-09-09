# 点 + 选文件时面板不收起

## 背景与目标

点文件行的 + 会弹出系统选文件窗。当前 `OpenPanelHost` 走 `StatusChrome.hideForPrompt()`，把菜单栏面板 `orderOut` 并透明度为 0。人看见整个面板收掉。选完才回来。

完成等级：功能可用。

## 当前行为

- `hideForPrompt` 对所有 ≥ statusBar 的窗：忽略鼠标、alpha 0、降到 `.normal`、`orderOut`。
- 这是给辅助功能授权框用的；选文件不该整窗消失。
- `specs/open-panel-front` 只要选择窗不被挡住，没有要求藏面板。

## 范围

- 点 +、设置里选文件夹 / 可执行文件：面板保持可见。
- 选择窗仍在面板前面，能点到。
- 选文件期间不进入闲时淡出。
- 授权系统框仍走 `hideForPrompt`。

## 非目标

- 不改进货规则，不覆盖原件。
- 不把选文件做成面板内嵌浏览器。

## 方案

- `OpenPanelHost` 改 `lowerForPicker`：只把 statusBar 窗降到 `.floating`，不 `orderOut`、不改透明度。
- 选择窗层级抬到 statusBar 之上。
- `PanelIdle.shouldRecess` 在 prompting 时为假。
- 关掉选择窗后 `restore`，面板仍在菜单栏层。

## 验收

1. 点 +：面板仍在，选择窗在前面。
2. 选完或取消：面板仍可见，回到菜单栏层。
3. 授权辅助功能仍会先藏面板。
4. `swift run DropAgentCheck` 与 `--e2e` 通过。

## 验证

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```
