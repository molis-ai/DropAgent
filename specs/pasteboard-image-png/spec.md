# 拖出的图必须是真 PNG

## 背景目标

`01` / `03` 规定图拖出带 `public.png`（或 TIFF）。现在 JPEG / HEIC 条目把原文件字节当成 PNG 味道交出去，对方按 PNG 解会坏。

## 当前行为与问题证据

`PasteboardService.representation(forStaged:)` 的 `.image` 分支：`pngData = Data(contentsOf: part.url)`，不看格式。

## 范围

- 文件味道仍是 Inbox 里的原件（jpg 还是 jpg）。
- `pngData` / `public.png` 只在能交出 PNG 魔数时出现：已是 PNG 则原样；否则用 `NSImage` 转一层。
- 转不了就不带 PNG 味道，仍可拖文件。
- 网站条的截图同样只在真是 PNG 时带图味道。

## 非目标

- 不改标签文案（图片仍叫 PNG）。
- Developer ID。

## 验收

1. JPEG 条目：`fileURLs` 指向 `.jpg`；`pngData` 以 `89 50 4E 47` 开头，不是 JPEG 头。
2. 真 PNG 条目：`pngData` 与文件字节一致。
3. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
```
