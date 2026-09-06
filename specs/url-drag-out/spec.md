# 链接拖出不落成 Inbox 文件

## 背景目标

`02-prototype-design.md` 第 6 节：拖「链接」到 Finder / 桌面不落成文件；文本框贴成 URL。现在 URL 条带着 Inbox 里的 `link.txt`，拖到桌面会落下这份副本。

## 当前行为与问题证据

`PasteboardService.representation(forStaged:)` 对 `.url` 把 `item.parts` 的文件 URL 放进 `fileURLs`。CLIP 要落下 `clip.txt`；链接不要。

## 范围

- 未跑完的 URL 条：`fileURLs` 为空，`plainText` 和 `webURL` 是该链接。
- `copy` 到剪贴板后，按「只要文件 URL」读不到本地文件。
- 跑完有 `output` 的仍按结果文件交。

## 非目标

- Developer ID、真人拖到 Finder 的 webloc 行为、改 WEB 文件夹拖出。

## 使用场景

架子上有一条网址。拖到备忘录：贴成 URL。拖到桌面：不落下 Inbox 里那份 `link.txt`。

## 方案与关键决策

`.url` 只带文字和 `webURL`，不带 staged file。

## 输入输出与依赖

输入：kind `.url` 的 Item。输出：`PasteboardRepresentation`。依赖现有 `copy` / `itemProvider`。

## 文件 / 模块边界

- `macos/Packages/DropAgentPasteboard/Sources/PasteboardService.swift`
- `macos/Check/main.swift`

## 验收标准

1. Check：URL 条 `fileURLs` 为空，`plainText` 与 `webURL` 等于源链接。
2. Check：`copy` 后 `urlReadingFileURLsOnly` 读到空；能读到链接文字。
3. Check 全绿。CLIP 拖出仍落 `clip.txt`。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
```

## 假设与开放问题

Finder 若把 `public.url` 收成 webloc，那是系统行为，不交 Inbox 文件即满足本条。
