# 架子上的图片能点开看；终端井启动时不留空

## 背景目标

`01` 接收图片。拖进一张截图后，「结果」是灰的，动作区也没有预览，人没法确认是不是刚那张图。发给 TUI 时 `ptyLive` 在进程一启动就变 true，「正在打开 Grok…」几乎看不到，预览 `08-sent` 是一块空黑。

## 当前行为与问题证据

- `currentResult()` 只认 done / failed / sent / web，不认 `kind == .image`。
- `TerminalHostView.consumePending` 在 `startProcess` 当下就把 `ptyLive = true`，覆盖层立刻撤掉。
- 预览 `08-sent`：井是空的。

## 范围

- 选中图片条，「结果」可点，里面看图。单击仍停在「动作」。动作区一行：「点「结果」看这张图。」
- 启动 TUI：先保持 `ptyLive = false`，井上写「正在打开 {引擎}…」。收到终端标题，或 0.45 秒后，再揭开井。
- 预览 `08c-opening` 能读到「正在打开 Grok…」；`08-sent` 井里有字，不是空黑块。
- 预览 `14-image` / `14b-image-result`：动作区 Recipe 在；结果 Tab 能看到图。

## 非目标

- 不做 PDF 阅读器。
- 不解析 TUI 画面。
- 不改 Capture / Job / 拖出。
- Developer ID。

## 使用场景

1. 从桌面拖进一张截图，点「结果」确认是那张，再总结或发给 Grok。
2. 点发送后，井上先出现「正在打开 Grok…」，随后才是 Grok 画面，不闪一块空黑。

## 方案与关键决策

`currentResult()` 在 web 之后认 image。图片用 `NSImage(contentsOf:)` 读 `parts` 或 `sourceURL`。PTY：`setTerminalTitle` 或 0.45s 超时揭井。预览且 `ptyLive`、尚未 `startProcess` 时，把 `ttyLines` 喂进井。

## 输入输出与依赖

输入：架子上的 image；TUI `startProcess`。输出：只改 App 面板。内核包不动。

## 文件 / 模块边界

- `macos/App/AppSession.swift`：`currentResult()`
- `macos/App/PanelRootView.swift`：图片 peek / 结果预览
- `macos/App/TerminalHostView.swift`：揭井时机、预览喂字
- `macos/App/PanelPreview.swift`：`08c-opening`、`14-image`、`14b-image-result`
- `design/modules/ai-pane.md`、`02-prototype-design.md`、`specs/tui-room/spec.md`

## 验收标准

1. 预览 `14-image`：动作 Tab，Recipe 可见，有「点「结果」看这张图。」
2. 预览 `14b-image-result`：结果 Tab，能看到图，有拖出。
3. 预览 `08c-opening`：终端 Tab 写「正在打开 Grok…」，不是空黑块。
4. 预览 `08-sent`：井里有字（至少一行投递记录）。
5. Check 全绿；`--e2e` 仍能把材料打进 Grok。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

0.45 秒是揭井上限，不是等 Grok 画完。标题回调会提前揭开。
