# 抓页表格和引用要像 Markdown，结果页也按这个看

## 背景目标

`01` 抓页交出正文 Markdown。现在 `HTMLMarkdown` 会剥 `<table>` / `<blockquote>` 标签，格子和引用变成一串字。点「结果」也认不出 `| 列 |` 和 `> 引用`。文档页对这批用户很常见。

## 当前行为与问题证据

Check 只验标题、链接、强调、`pre`/`code`。`</blockquote>` 被直接换成换行。`ResultMarkdown` 只认标题、列表、段落、围栏。

## 范围

- `<table>`：每行 `th`/`td` 变成 Markdown 表（第一行当表头，补分隔行）。单元格里已转好的链接保留。
- 套中套的 `<table>` 不硬解析，剥标签当普通字。
- `<blockquote>`：每行前面加 `> `。
- 结果页：连续的 `| … |` 行用等宽代码块显示；连续的 `> ` 行当成引用（左缩进，不用彩色竖条）。
- 预览 `07b-web-result` 的 `page.md` 带一行表和一句引用。
- 不做 colspan、语法高亮、把表画成格子控件。

## 非目标

- 完整 HTML 解析器、整站、登录 Cookie。
- Developer ID。

## 使用场景

⌃⌥W 抓到带参数表和提示引用的文档，点「结果」能看出列和引用，发给 Grok 时 `page.md` 也还是表。

## 方案与关键决策

表格在链接/强调之后、剥标签之前转，这样格里的 `[字](url)` 还在。结果页窄，表用等宽块，不新做网格。

## 输入输出与依赖

输入：HTML 或已有 Markdown。输出：Markdown 表/引用；结果页 heading / item / paragraph / code / quote。`HTMLMarkdown` 仍在 Capture；`ResultMarkdown` 仍在 App。

## 文件 / 模块边界

- `macos/Packages/DropAgentCapture/Sources/HTMLMarkdown.swift`
- `macos/Check/main.swift`
- `macos/App/ResultMarkdown.swift`
- `macos/App/PanelRootView.swift`
- `macos/App/PanelPreview.swift`
- `macos/App/AppE2E.swift`

## 验收标准

1. Check：两列表转成含 `| A |`、`---`、`| 1 |` 的 Markdown；格里相对链接仍是 `[go](https://example.com/x)`。
2. Check：`<blockquote><p>Note</p></blockquote>` 含 `> Note`。
3. Check：原有 article / 链接 / 围栏代码仍过。
4. `--e2e`：表三行进同一个 code 块；`> Note` 进 quote。
5. 预览 `07b-web-result` 能读到表头或引用，不只是糊成一段。
6. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

空表丢掉。只有一行的表也出表头+分隔，没有数据行。
