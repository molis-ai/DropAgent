# App 端到端：粘贴进 CLIP，拖出 clip.txt

## 背景目标

`03` §9.5、`02` §6：剪贴板那条，字则落成 `.txt`。内核 Check 已覆盖 CLIP 落地、RTF 解析、剪贴板图。App `--e2e` 进货只走过文件板的 `admitPasteboard`，从没点过「粘贴」，也没拖出过 `clip.txt`。

## 当前行为与问题证据

`pasteFromClipboard()` 写死 `SystemClipboard()`（读通用剪贴板）。e2e 为了不改用户剪贴板，不能直接写 `.general`。面板这条粘贴 → 架子 → 拖出，壳上没有证据。

## 范围

- `pasteFromClipboard` 可注入 `ClipboardReading`；菜单栏 ⌘V / 「粘贴」仍默认读系统剪贴板。
- `--e2e`：独立剪贴板写纯文本 → 粘贴 → CLIP 条 → 拖出 `clip.txt`，正文一致。
- `--e2e`：独立剪贴板只写 RTF → 粘贴 → CLIP，正文是抽出来的纯文本。
- `--e2e`：独立剪贴板写 PNG → 粘贴 → 图片条 → 拖出 `clipboard.png`，PNG 魔数在。
- 测完删条。不改四条调用链。

## 非目标

- Developer ID。
- 不碰用户 `.general` 剪贴板。
- 不做富文本阅读器。

## 使用场景

⌘V 贴一段口径，从架子拖到桌面得到 `clip.txt`。从 Word 只复制出 RTF 时，粘贴仍进架子。

## 方案与关键决策

e2e 用 `NSPasteboard.withUniqueName()` + `PasteboardClipboard`，和顶边/图标同一套 `ClipboardPayload.from`。

## 输入输出与依赖

输入：测试文字 / RTF / PNG。输出：桌面 `clip.txt` / `clipboard.png`。

## 文件 / 模块边界

- `macos/App/AppSession.swift`
- `macos/App/AppE2E.swift`
- 本 spec

## 验收标准

1. `--e2e`：纯文本粘贴后落地 `clip.txt`，正文是测试句。
2. `--e2e`：仅 RTF 的板粘贴后 kind 是 CLIP，架子正文含测试句。
3. `--e2e`：PNG 粘贴后落地 `clipboard.png`，文件以 PNG 魔数开头。
4. `--e2e`：随后抓页、Grok 发送仍过。
5. Check 全绿。正式启动仍读系统剪贴板。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

无。
