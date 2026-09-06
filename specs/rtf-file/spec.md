# 拖进 .rtf 文件不要冒充文稿

## 背景目标

`generic-file` 把认不出的扩展名收成 `file`，并记下「`.rtf` 若不被 UTType 认成文本会进 file」。本机 `public.rtf` **符合** `public.text`，不符合 `public.plain-text`。所以拖进 Word / 备忘录另存的 `.rtf` 会变成 MD「文稿」，翻译 / 转 MD 会亮，结果页按 Markdown 看一堆控制符。

剪贴板里的 RTF 已经抽成纯文本进 CLIP，这条不改。

## 当前行为与问题证据

`IngestService.kind(for:)`：扩展名不是 md/txt 时，`UTType.conforms(to: .text)` 为真就返回 `.markdown`。`public.rtf` 对 `.text` 为真。

## 范围

- 本地 `.rtf` / `.rtfd` → `file`，标签 `RTF` / `RTFD`，类型字「文件」。
- Recipe：总结 / 抽取 / 翻译 / 脱敏 / 转 MD 不含 file，所以这些按钮暗；仍可发给 TUI、拖出原文件。
- 剪贴板只有 RTF：仍是 CLIP。
- Check 覆盖上述两条。
- 不把 html / json 一并改掉。

## 非目标

- 不做 RTF 阅读器，不抽文件里的纯文本当 CLIP。
- Developer ID。

## 使用场景

从 Finder 拖进 `口径.rtf`：架子上是 RTF 文件，不是文稿。点「结果」说明拖出打开。要当字处理，仍用 ⌘V 贴那段字。

## 方案与关键决策

在 UTType `.text` 兜底之前，按扩展名把 rtf/rtfd 定为 file。不改成「只认 plainText」——那会把 json/html 也改掉，超出这一刀。

## 输入输出与依赖

输入：本地 `.rtf` / `.rtfd` URL。输出：`Item.kind == .file`。依赖现有 Inbox 复制。

## 文件 / 模块边界

- `macos/Packages/DropAgentIngest/Sources/IngestService.swift`
- `macos/Check/main.swift`
- `design/modules/ingest.md` 类型表补一句
- `specs/generic-file/spec.md` 开放问题改成已决
- 本 spec

## 验收标准

1. Check：`note.rtf` 进货 kind 是 file，`displayTag` 是 `RTF`。
2. Check：只写 RTF 的剪贴板仍是 CLIP。
3. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
```

## 假设与开放问题

json 仍可走 markdown（结果页 pretty-print，见 `specs/html-json-inspect`）。html / htm 已收成 file。
