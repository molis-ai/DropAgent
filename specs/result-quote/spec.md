# 结果页引用要看得出，仍不用彩色竖条

## 背景目标

`capture-table` 已把 `> ` 收成 `.quote`，并规定左缩进、不用彩色竖条。预览 `07b-web-result` 里「For illustration only.」和上一句正文同色同号，截图会把两句并成一段。抓页引用等于没显示出来。

## 当前行为与问题证据

`resultMarkdown` 对 `.quote`：12pt、`Palette.muted`、左缩进 10pt。段落也是 12pt `muted`。解析对，画面不对。

## 范围

- 引用：斜体、左缩进 12pt、左侧 1px `Palette.line`（产品自己的分割线，不是彩色竖条）。
- 字色仍用 `muted`，对比度不降到 `faint`。
- 预览 `07b-web-result` 能把引用和上一句正文分开看。
- 不改 `HTMLMarkdown`、不改 `ResultMarkdown.blocks` 契约、不加引用卡片底。

## 非目标

- Developer ID。
- 不把表画成格子控件。
- 不给引用加彩色左边条。

## 使用场景

⌃⌥W 抓到带提示引用的文档，点「结果」能看出哪句是引用，再决定发给 Grok。

## 方案与关键决策

视觉只动 App 的 `.quote` 绘制。1px 分割对齐 `02` / `DESIGN.md`；斜体是引用的常规字态，不是新装饰。

## 输入输出与依赖

输入：已解析的 `.quote`。输出：结果 Tab 画面。依赖现有 `ResultMarkdown`。

## 文件 / 模块边界

- `macos/App/PanelRootView.swift`
- 本 spec
- 预览仍用 `07b-web-result`

## 验收标准

1. `--e2e`：`> Note` 仍进 quote 块（解析不变）。
2. 预览 `07b-web-result`：引用句斜体、左侧有 1px 分割，不和上一句糊成一段。
3. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

无。
