# 终端把位子让给 PTY

## 背景目标

发给 TUI 后自动切到「终端」。现在投递记录占掉约 72pt，架子默认还是 188pt，Grok/Claude 的画面只剩一条缝。人看不清会话，只能拖分隔条。

## 当前行为与问题证据

`--e2e` 的 `e2e-tty.png`：架子仍很高；「Grok · 本机会话 / 材料 / ›」叠在 PTY 上面；Grok 自己的界面已经被截成路径和一行提示。

## 范围

- 进程在跑：投递记录收成一行（引擎 · 最近材料），PTY 占满剩余。`startProcess` 后先保持 `ptyLive = false`，近黑井上写「正在打开 {引擎}…」；收到终端标题或 0.45 秒后再揭开，避免空井。打开中不要盖一张白纸。
- 进程结束：再展开记录，并显示「会话不在了」。
- 进程结束：再展开记录，并显示「会话不在了」。
- 切到终端时，若架子高于贴合行高与 108pt 的较小值，先收到该高度；**不写入** `panel.json`。离开终端时恢复刚才的高度，除非人已经拖过分隔条。
- Reduce Motion 时高度仍改，不做额外动画。

## 非目标

- 不解析 TUI 画面、不模拟按键。
- 不改 `TUI.send` / Job / Capture。
- 不把这次临时高度存成用户偏好。

## 方案

`AppSession` 记住进入终端前的 `listHeight`。`PanelRootView` 终端 Tab：`tuiProcessRunning` 时一行 caption，否则保持现有记录列表。原型「终端」场景同样：一行说明 + 终端井，不发明新业务规则。

## 验收

1. 预览 `08-sent`：终端进程在跑且 `ptyLive` 时，动作区不是三行日志压着空井；能看到近黑终端井，井里有字。进程还没起来时（`08c-opening`）井是近黑底，写「正在打开 {引擎}…」，不是白纸卡片。
2. 切走终端后架子高度回到进入前（未拖过分隔条）。
3. Check 全绿；四条调用链不变。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
```
