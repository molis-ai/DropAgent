# 抓页正文里的图片收成 Markdown，结果页能看见

## 背景目标

`01` 抓页要交出正文 Markdown。`capture-code` 那刀故意不做 `<img>`。正文里的图被剥掉，只剩整页 `snapshot.png`。发给 Grok 的 `page.md` 看不到图在哪。

## 当前行为与问题证据

`HTMLMarkdown.convert` 在 `stripTags` 时丢掉 `<img>`。Check 没有图片样例。预览 `07b-web-result` 的 `page.md` 也没有图片行。结果页 `ResultMarkdown` 不认识 `![alt](url)`，会跟段落糊在一起。

## 范围

- `<img src>` 转成 `![alt](url)`。相对地址按页 URL 补成绝对 `http(s)`。`javascript:` / `data:` 只留 alt，不留地址。
- 没有 src 或解析不出地址：只留 alt；alt 也空则丢掉。
- 结果页：单独一行的图片语法画成说明 + 可点开的地址，不在面板里下载图片。整页截图仍是 `snapshot.png`。
- 预览 `07b-web-result` 的 `page.md` 带一张图，画面上能读到 alt 或地址。
- 仍先取 `article` / `main`；仍去 script/style。
- 不改四条调用链、不装扩展、不带登录 Cookie。

## 非目标

- Developer ID。
- 不把远程图画进结果页（不另发网络）。
- 不做 `<figure>` / `<picture>` / srcset 的完整解析。
- 不改 `isolationShown`。

## 使用场景

⌃⌥W 抓到带插图的文档。`page.md` 里有 `![示意图](https://…/fig.png)`。点「结果」能看见这是一张图、地址可打开。发给 Grok 时图地址还在。

## 方案与关键决策

Capture 只负责把标签收成 Markdown 链接形态。结果页当「有一张图」展示，视觉仍靠已有截图 part。和 `open-source-url` 一样：http(s) 可打开，其它丢掉。

## 输入输出与依赖

输入：HTML 字符串 + 可选 base URL；结果页 Markdown。输出：含 `![alt](url)` 的正文；结果 Tab 一行图说明。依赖现有 `resolvedHREF` / `SourceLink`。

## 文件 / 模块边界

- `macos/Packages/DropAgentCapture/Sources/HTMLMarkdown.swift`
- `macos/Check/main.swift`
- `macos/App/ResultMarkdown.swift`
- `macos/App/PanelRootView.swift`
- `macos/App/PanelPreview.swift`
- `macos/App/AppE2E.swift`
- 本 spec

## 验收标准

1. Check：`<img src="/x.png" alt="Logo">` 在 `https://example.com/page` 上变成 `![Logo](https://example.com/x.png)`。
2. Check：`javascript:` / `data:` 的 src 不进 Markdown 地址；alt 还在。
3. `--e2e`：`![示意图](https://example.com/fig.png)` 解析成图片块，不是普通段落。
4. 预览 `07b-web-result` 能读到图的 alt 或 `https://` 地址。
5. Check 全绿。原有 article / 链接 / 代码围栏仍过。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

`<img>` 若写在 `<pre>` 里，会先被收进代码围栏，不再转成图片语法。
