# 其他文件进架子，不要冒充文稿

## 背景目标

`01` 接收文件。现在认不出的扩展名一律 `markdown`，标签 MD、类型字「文稿」，翻译 / 转 MD 还会亮。拖进 `archive.zip` 或 `.docx` 像一篇字。

## 当前行为与问题证据

`IngestService.kind(for:)` 最后 `return .markdown`。Check 里坏 `.webloc` 也当成文稿。`03` 的 kind 表没有 generic file。

## 范围

- 新 kind：`file`。标签优先 1–4 位扩展名（`ZIP` / `DOCX`），否则 `FILE`；类型字「文件」。
- 判定：不是 PDF / 图 / md·txt / 文件夹 / URL 的本地文件 → `file`。纯文本 UTType 仍是 markdown。
- Recipe：按 `01` 表。总结 / 抽取 / 翻译 / 脱敏 / 转 MD **不**接 generic file；「新交付」接（多文件组合）。仍可发给 TUI、拖出文件。
- 拖出：只要 file URL。动作区 / 结果：点开说明拖出打开（HTML 抽正文，见 `result-readable`）。不做网页阅读器。
- 更新 `03` kind 表、Ingest / Pasteboard 模块说明。

## 非目标

- 不解析 zip / Office 内部结构。
- 不把 Recipe 接到 Grok。
- Developer ID。

## 使用场景

拖进 `报价.zip`：标签 ZIP，类型「文件」。翻译是暗的。发给 Grok 或拖到桌面。

## 方案与关键决策

补 kind，不把 zip 继续塞进 markdown。坏 webloc 也走 file。

## 输入输出与依赖

输入：任意本地文件 URL。输出：Item.kind `.file`。依赖现有 Inbox 复制。

## 文件 / 模块边界

- `macos/Packages/DropAgentShelf/Sources/Item.swift`
- `macos/Packages/DropAgentIngest/Sources/IngestService.swift`
- `macos/Packages/DropAgentJob/Sources/RecipeCatalog.swift`
- `macos/Packages/DropAgentPasteboard/Sources/PasteboardService.swift`
- `macos/App/PanelRootView.swift`
- `macos/Check/main.swift`
- `03-tech-architecture.md`、`design/modules/ingest.md`、`design/modules/pasteboard.md`

## 验收标准

1. Check：`archive.zip` 进货 kind 是 file，`displayTag` 是 `ZIP`。
2. Check：翻译 / 总结的 `acceptedKinds` 不含 file；新交付含 file。
3. Check：坏 webloc 是 file，不是 markdown。
4. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
```

## 假设与开放问题

`.rtf` / `.rtfd` 本地文件进 `file`（见 `specs/rtf-file`）。剪贴板 RTF 仍是 CLIP。
