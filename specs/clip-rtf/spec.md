# CLIP 拖出要落下 txt，RTF 粘贴也要进得来

## 背景目标

需求第 11 节：剪贴板那条，字则落成 `.txt`，文本框贴成字。从备忘录 / Word 复制常常只有 RTF，没有 `public.utf8-plain-text`。现在 CLIP 拖出没有 Check；`ClipboardPayload.from` 只读 `.string`。

## 当前行为与问题证据

- `PasteboardService` 对 `.clip` 带 file URL + 正文，但 Check 没走过落地。
- `ClipboardPayload.from`：没有 `.string` 就当空板。

## 范围

- CLIP 拖出：`fileURLs` 指向 `clip.txt`，`plainText` 是正文；落到桌面能读到原文。
- 剪贴板只有 RTF：仍解析成 `.text`，`admitClipboard` 进 CLIP。
- 菜单栏 / 顶边登记 HEIC（相册常见）。
- 不改四条调用链。

## 非目标

- Developer ID、顶边真人拖、做富文本阅读器。

## 使用场景

⌘V 贴了一段口径，从架子拖到备忘录：落下字。从 Word 复制一段只带 RTF 的字，点「粘贴」仍进架子。

## 方案与关键决策

RTF 用 `NSAttributedString` 抽纯文本，排在 `.string` 之后、空板之前。

## 输入输出与依赖

输入：CLIP Item、RTF `NSPasteboard`。输出：落地 txt、CLIP 条目。依赖现有 `itemProvider` / `admitClipboard`。

## 文件 / 模块边界

- `macos/Packages/DropAgentIngest/Sources/PasteboardClipboard.swift`
- `macos/Packages/DropAgentPasteboard` 只加 Check，不改形态则不动
- `macos/Check/main.swift`
- `macos/App/PlatformAdapters.swift`：HEIC

## 验收标准

1. Check：CLIP 条 `plainText` 是正文；拖出落到桌面的文件名是 `clip.txt`，内容一致。
2. Check：只写 RTF 的板 → `.text`，进货 kind 是 CLIP。
3. `IncomingDrop.draggedTypes` 含 HEIC。
4. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
```

## 假设与开放问题

无。
