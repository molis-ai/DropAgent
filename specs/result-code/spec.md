# 结果页把围栏代码当代码看，不要摊成一段字

## 背景目标

`capture-code` 已经让 `page.md` 带 ` ``` ` 围栏。点「结果」看网站或总结时，`markdownBlocks` 仍按段落拼行，围栏标记和命令糊成一句。这批用户抓的就是带安装命令的文档。

## 当前行为与问题证据

`PanelRootView.markdownBlocks` 只认标题、列表、段落。围栏行被 `trimmingCharacters` 后丢进段落，空行一拼，`npm i` 不再像代码。`07b-web-result` 的 `page.md` 没有围栏样例。Check 不 import App，这条没有内核单测。

## 范围

- 结果区 Markdown（Job 的 `.md`、网站 `page.md`、未跑的文稿 `.md`）认围栏：单独一行的 ` ``` ` 开闭。
- 围栏内原样保留缩进和空行，用等宽 + 炭灰底显示；开闭行本身不出现在正文里。
- ` ```swift ` 这种只当开门，不把语言名画成标签。
- 未闭合的围栏：后面都当代码。
- CLIP 仍是纯文本。JSON 结果仍走等宽 pretty-print，不走围栏。
- 预览 `07b-web-result` 的 `page.md` 带一条围栏命令，画面上命令在代码块里，不是跟说明挤一行。
- `--e2e` 调生产解析，断言围栏变成 code 块。

## 非目标

- 不做表格、引用、语法高亮、行号。
- 不改 HTMLMarkdown 生产规则。
- Developer ID。

## 使用场景

⌃⌥W 抓到一篇带 `npm i` 的文档，点「结果」能看出那是命令。总结里若带命令，同样不摊开。

## 方案与关键决策

解析从 View 里抽成 `ResultMarkdown`（仍在 App，不是新内核包）。围栏优先于标题/列表。CLIP 不是文稿，保持纯文本。

## 输入输出与依赖

输入：Markdown 字符串。输出：heading / item / paragraph / code 块。依赖现有结果 Tab。

## 文件 / 模块边界

- `macos/App/ResultMarkdown.swift`（新，仅 App）
- `macos/App/PanelRootView.swift`
- `macos/App/PanelPreview.swift`
- `macos/App/AppE2E.swift`
- 本 spec

## 验收标准

1. `--e2e`：`# Keep` + 围栏 `npm i` + 段落后，解析出 heading / code(`npm i`) / paragraph；code 里没有包一层 `` `npm i` ``。
2. 预览 `07b-web-result` 能读到围栏里的命令（如 `curl`），且看起来是代码块不是普通段落。
3. 预览 `06-result` 仍能读到「总结」标题和列表。
4. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

围栏里如果再出现 ` ``` `，按关门处理（常见 Markdown 行为）。
