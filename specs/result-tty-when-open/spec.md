# 结果页「终端」只在已经有会话时出现

## 背景目标

结果页的「拖出 / 复制 / 终端」一直在。Recipe 跑完或只是点开 PDF 时，底下 Tab「终端」是灰的，结果页那颗「终端」却能强行切过去。井里是「发送后，Grok 会出现在这里」。人刚看完总结，点「终端」像坏了。发给 TUI 之后去终端继续说，才是这条按钮的活。

## 当前行为与问题证据

`resultBody`：`Button("终端") { session.aiTab = .tty }`，不看 `tuiSessionDirectory` / `ttyLines`。Tab 栏同一条件会禁用。预览 `06-result`、`03d-pdf-result` 都有这颗按钮；当时还没发送。`web-inspect` 要求已进终端的结果仍能去终端。

## 范围

- `canOpenTerminalTab`：已有会话目录或已有投递记录。
- 结果页只在这时画「终端」。
- 预览 `06-result` / `03d-pdf-result` 没有这颗按钮；`08b-sent-result` 有。
- `--e2e`：进货后不能开终端 Tab；发送后可以。
- 不改发送、不改 Tab 栏禁用条件、不改四条调用链。

## 非目标

- Developer ID。
- 不在结果页代发 TUI。发给终端仍走底下发送 / 拖到 AI 区。

## 使用场景

总结跑完点「结果」：只有拖出和复制。先 ⌃⌥W 再发送后，结果页可以点「终端」回去说话。

## 方案与关键决策

结果页按钮和 Tab 栏用同一套「有没有会话」判断。按钮不再绕过禁用。

## 输入输出与依赖

输入：`tuiSessionDirectory`、`ttyLines`。输出：结果页是否画「终端」。

## 文件 / 模块边界

- `macos/App/AppSession.swift`
- `macos/App/PanelRootView.swift`
- `macos/App/AppE2E.swift`
- 本 spec

## 验收标准

1. 预览 `06-result`、`03d-pdf-result` 结果区没有「终端」按钮。
2. 预览 `08b-sent-result` 有「终端」。
3. `--e2e`：admit 后 `canOpenTerminalTab == false`；send 后为 true。
4. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

无。
