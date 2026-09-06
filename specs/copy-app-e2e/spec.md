# App 端到端：复制出剪贴板，URL 不落成文件

## 背景目标

`03` §9.5 剪贴板进出：进货刚用独立剪贴板走完粘贴。拿走还有一条「复制」，壳上仍写死系统通用剪贴板，`--e2e` 从没点过「复制」，也没贴过一条 URL。

## 当前行为与问题证据

`copyItem` 调 `PasteboardService.copy` 默认 `.general`。e2e 不能写用户剪贴板。内核 Check 已覆盖 URL 条 `fileURLs` 为空；App 进程没有粘贴 URL → 复制 → 没有本地文件这条。

## 范围

- `copyItem` 可注入 `NSPasteboard`；面板「复制」/ ⌘C 仍默认 `.general`。
- `--e2e`：CLIP 粘贴后 `copyItem` 到独立板，板上是测试句。
- `--e2e`：PNG 粘贴后 `copyItem` 到独立板，能读到图。
- `--e2e`：独立板贴 `https://…` → URL 条 → 复制后没有文件 URL，有链接文字。
- 不写用户 `.general`。不改四条调用链。

## 非目标

- Developer ID。
- 真人 ⌘C 进别的 App。
- 不把 URL 拖出改成 webloc。

## 使用场景

点「复制」把 CLIP 正文交给备忘录。架子上一条网址，复制后文本框能贴链接，桌面不会多一份 Inbox 里的 `link.txt`。

## 方案与关键决策

复制仍走 `PasteboardService.copy`。e2e 用 `NSPasteboard.withUniqueName()`。

## 输入输出与依赖

输入：测试文字 / PNG / URL。输出：独立剪贴板内容；架子 kind。

## 文件 / 模块边界

- `macos/App/AppSession.swift`
- `macos/App/AppE2E.swift`
- 本 spec

## 验收标准

1. `--e2e`：CLIP 复制到独立板，正文是测试句。
2. `--e2e`：PNG 复制到独立板，能读到图像。
3. `--e2e`：URL 粘贴后 kind 是 URL；复制后 `urlReadingFileURLsOnly` 为空，字符串是该链接。
4. `--e2e`：随后抓页、Grok 发送仍过。
5. Check 全绿。正式启动仍写系统剪贴板。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

无。
