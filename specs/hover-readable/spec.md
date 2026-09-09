# 悬停预览：Markdown 和 HTML 可读

## 背景与目标

悬停已经能读到正文，但把换行压成一行，Markdown 的标题、列表、表格都糊成生字。HTML 虽会抽成 Markdown，接着也被压平。结果区已经有可读渲染，悬停应对齐同一套，只是更紧。

完成等级：功能可用。

## 当前行为与问题

- `ItemPeek.hoverText` 用正则把所有空白收成空格，再 `Text` 画出来。
- `# 标题`、`- 列表`、`| 表 |` 原样出现。
- `.html` 先 `ReadableHTML` 再走同一条压平。
- 结果区 `ResultBodyView.markdown` 已有标题层级、列表、表格、引用。

## 范围

- 悬停：Markdown 用紧凑版结果区渲染；HTML 抽正文后再渲染，并保留「抽出的正文，不是网页预览」。
- JSON 仍等宽 pretty；代码仍等宽；PDF / 链接 / 文件夹不装成 Markdown。
- 悬停不拉远程图、不嵌网页、不点链接。指针在预览卡内不关、过长可滚，见 `specs/hover-stay-scroll/spec.md`。
- 卡片上的短摘要仍可压成一行。

## 非目标

- 不改内核业务规则，不覆盖原件。
- 不把悬停做成完整结果页或 WKWebView。
- 不做语法高亮、任务列表、脚注。

## 方案

- `ItemPeek.hoverBody` 保留换行，按类型给出 markdown / json / code / plain。
- `ResultBodyView.markdown(..., compact: true)`：更小标题、更紧行距；图片只出说明，避免悬停去拉网。
- 过长正文在换行处截断，窗口高度仍封顶约 320。

## 验收

1. 悬停 `.md`：能看出标题、列表、表格，不是一串 `#` 和 `|`。
2. 悬停 `.html`：看到抽出的标题和段落，看不到 `<script>`；有「不是网页预览」一句。
3. 悬停 JSON 仍是格式化正文；PDF 仍是抽字，不是当 Markdown。
4. `swift run DropAgentCheck` 与 `--e2e` 通过。

## 验证

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```
