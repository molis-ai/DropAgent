# 结果区：Markdown 好看一点，HTML 抽成可读正文

## 背景目标

结果区已经能「看见」Markdown，但表格被糊成代码块、标题不分大小、图片只出说明和网址。本地 `.html` 故意不当网页看，只剩「拖出去打开」。Recipe 若吐出 `.html`，还会当 Markdown 把标签画出来。

按推荐：Markdown 把表格、标题层级、图片看清楚；HTML 抽成和抓页一样的可读正文，不嵌网页。

## 当前行为与问题证据

- `ResultMarkdown` 已认表格行，但 `flushTable` 整段丢进 `.code`。e2e 断言 `| A | B |` 是 code。预览 `07b-web-result` 的 `page.md` 已有表和 `![...](https://...)`，画面上表是代码、图不显示。
- 标题一律 13pt semibold，`#` 和 `###` 看起来一样。
- `.image` 只画 alt + 链接。
- 本地 `.html` → kind `file`，「不做阅读器」（`html-json-inspect`）。`resultDocument` 非 json 都走 `resultMarkdown`。

## 范围

- Markdown 块：标题记下层级（1–6）；表格解析成表头 + 行（跳过 `| --- |` 分隔行）；图片仍是 `.image`。
- 画面：H1 略大衬线，H2/H3 递减；表用发丝格，不是 Dashboard 卡片；本地相对路径图片能显示；`http(s)` 图片用无 Cookie 的临时会话拉，失败则退回 alt + 链接。不跟 `file://` 逃出材料目录。不加载 `javascript:` / `data:`。
- 本地 `.html` / `.htm`（未跑）和 Recipe 产出的 `.html`：用 Ingest 公开的 `ReadableHTML`（内部仍是 Capture 的 `HTMLMarkdown`）抽成 Markdown 再画。kind 仍是 `file`，翻译等动作规则不变。加一句人话：这是抽出的正文，不是网页预览。
- App 不 import Capture。

## 非目标

- 不嵌 WKWebView，不还原 CSS / 脚本。
- 不做语法高亮、行号、任务列表、脚注。
- 不改四条调用链、不覆盖原件。
- 不把 html 改成 markdown kind（否则会假装文稿、动作规则跟着变）。

## 使用场景

1. 总结带二级标题和一张两列表：结果区能看出层次和格子，不是代码围栏。
2. `page.md` 里 `![示意图](https://example.com/fig.png)`：能显示图；拉不下就仍是说明 + 链接。
3. 拖进 `报价.html`：点结果能读抽出的标题和段落，架子上仍是 HTML 文件，翻译仍是暗的。
4. Recipe 产出 `translated.html`：看到正文，不是一堆标签。

## 方案与关键决策

- 解析仍在 App 的 `ResultMarkdown`。HTML 转换挂在 Ingest 公共 API，满足「App 不 import Capture」。
- 远程图只为阅读；临时会话、体积上限，不把这说成 Workspace。
- 相对图必须落在该文稿所在目录内。

## 输入输出与依赖

输入：Markdown 字符串、可选文稿目录、HTML 原文。  
输出：块（含 heading 层级、table）、画面。  
依赖：现有结果 Tab、`HTMLMarkdown`、`SourceLink`。

## 文件 / 模块边界

- `macos/App/ResultMarkdown.swift`、`MarkdownImage.swift`、`PanelRootView.swift`、`PanelPreview.swift`、`AppE2E.swift`、`Copy.swift`
- `macos/Packages/DropAgentIngest/Sources/ReadableHTML.swift`
- `design/modules/ai-pane.md`、`ingest.md`、`02-prototype-design.md`
- `specs/html-json-inspect/spec.md` 改口：kind 仍是 file，结果区可以抽正文
- 本 spec

## 验收标准

1. `--e2e`：`# Keep` 是 heading 层级 1；`| A | B |` 表是 table 不是 code；图片块仍在。
2. Check：`ReadableHTML.markdown` 对带 script 的 html 抽出标题、去掉 script；html 进货 kind 仍是 file。
3. 预览 `06-result` 能看出二级标题和表；`07b-web-result` 的表不再是代码块。
4. App 源码仍无 `import DropAgentCapture`。
5. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
```

## 假设与开放问题

远程图依赖外网；预览里 example.com 的 og 图可能拉不到，那时仍显示链接。不为此改抓页。
