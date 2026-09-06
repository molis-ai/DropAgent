# 结果页拖出钉在输入框上方

## 背景目标

`02` 的拿走是拖走或复制。结果页长正文（网站 Markdown、截图）会把「拖出 / 复制」滚出画面。人点开「结果」却拿不到货。

## 当前行为与问题证据

`resultBody` 把正文和按钮放在同一个 `ScrollView` 里。预览 `07b-web-result`：能读到 example.com 正文和截图，输入框上方看不到「拖出」。`08b-sent-result` 同样要把结果区滚到底才有按钮。短文稿 `06-result` 碰巧看得见，不是结构保证。

## 范围

- 结果 Tab：正文仍可滚；「拖出 / 复制」以及有会话时的「终端」钉在滚动区下方、输入框上方。
- 「已复制到剪贴板」跟按钮走，不跟正文滚走。
- 没有当前结果时不画这排按钮（仍是那句空提示）。
- 动作 Tab、终端 Tab、六个 Recipe、发送、拖出载荷不变。
- 预览 `07b-web-result` / `08b-sent-result` 在输入框上方能读到「拖出」。

## 非目标

- Developer ID。
- 不把架子行上的整行拖出改成钉住。
- 不改 Capture / Ingest / Pasteboard。
- 不把动作区 Recipe 也钉住。

## 使用场景

⌃⌥W 抓了一页，点「结果」确认正文。不滚就能拖文件夹出去，或复制正文。总结很长时同样。

## 方案与关键决策

结果内容与拿走动作拆开。ScrollView 只装正文；动作条用 1px 分割贴在 composer 上方。Composer 自己的顶部分割仍在，形成「正文 | 拿走 | 输入」三层。

## 输入输出与依赖

输入：`currentResult()`、`canOpenTerminalTab`、`copiedID`。输出：只改面板布局。依赖现有 `DragOutButton` / 复制 / 终端按钮。

## 文件 / 模块边界

- `macos/App/PanelRootView.swift`
- `macos/App/AppE2E.swift`
- `02-prototype-design.md`、`design/modules/ai-pane.md` 补一句布局
- 本 spec

## 验收标准

1. 预览 `07b-web-result`：正文仍在，输入框上方能读到「拖出」和「复制」，不必假设滚过结果区。
2. 预览 `08b-sent-result`：同样能读到「拖出」；有「终端」。
3. 预览 `06-result`、`03d-pdf-result`：仍有「拖出 / 复制」，没有「终端」。
4. `--e2e`：进货后切到结果，`currentResult()` 非空；发送后结果页仍可切。
5. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

无。
