# 抓页正文里的代码要变成 Markdown，不要摊成一段字

## 背景目标

第一版用户已经在本机用 Grok / Codex / Claude / Gemini。他们抓的文档页经常带 `<pre>` / `<code>`。现在 `HTMLMarkdown` 剥标签后代码和正文糊在一起，发给终端也不像代码。

## 当前行为与问题证据

`HTMLMarkdown.convert` 处理标题、列表、链接、强调，不处理 `pre` / `code`。Check 没有代码块样例。

## 范围

- `<pre>` → 围栏代码块（` ``` `），内部再剥一层标签。
- 围栏外的 `<code>` → 行内 `` `code` ``。
- 仍先取 `article` / `main`；仍去 script/style；相对链接规则不变。
- 不是完整 HTML 解析器：不做表格、不做语法高亮 class、不把 `<img>` 变成图片。

## 非目标

- Developer ID。
- 不抓整站、不带登录 Cookie。

## 使用场景

抓一篇带安装命令的文档：`page.md` 里命令在围栏里，发给 Grok 仍能当代码读。

## 方案与关键决策

在链接/标题替换之前先把 `<pre>` 换成围栏，避免里面的 `<code>` 再套一层行内反引号。

## 输入输出与依赖

输入：HTML 字符串 + 可选 base URL。输出：Markdown 字符串。只改 `HTMLMarkdown`。

## 文件 / 模块边界

- `macos/Packages/DropAgentCapture/Sources/HTMLMarkdown.swift`
- `macos/Check/main.swift`

## 验收标准

1. Check：`<pre><code>npm i</code></pre>` 变成围栏，内容含 `npm i`，围栏内没有嵌套的行内反引号包住整段。
2. Check：段落里 `<code>PATH</code>` 变成 `` `PATH` ``。
3. Check：原有 article / 链接 / 去 script 仍过。
4. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
```

## 假设与开放问题

`<pre>` 里若已有 Markdown 围栏标记，原样保留，不做转义。
