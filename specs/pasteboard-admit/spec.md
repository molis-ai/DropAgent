# 菜单栏和顶边的进货走系统剪贴板

## 背景目标

拖到菜单栏图标、顶边投放条，走的是 `NSPasteboard`，不是面板列表的 `NSItemProvider`。解析现在写在 App 适配器里，Check 覆盖不到；e2e 也只测了 Provider 那条。

## 当前行为与问题证据

- `EdgeDropView` / `StatusDropView` → `AppSession.admitPasteboard` → `IncomingDrop` → `SystemClipboard.payload`（在 App）。
- Check 测 `admitClipboard(MemoryClipboard)` 和 `admitProviders`，不读真 `NSPasteboard`。
- `--e2e` 用 `admitDrop(providers:)`。

## 范围

- `ClipboardPayload.from(pasteboard:)` 放到 Ingest（跟 `DropProviders` 一样吃 AppKit）。
- Check：文件、https 链接、纯文本、空板、剪贴板图（PNG 魔数）。
- 菜单栏图标和顶边登记 TIFF / JPEG / 通用图，不只 PNG。
- `--e2e` 进货改走 `admitPasteboard`（图标 / 顶边同一条链）。
- App 的 `IncomingDrop` 只做空板与错误映射，不自己认 UTI。

## 非目标

- Developer ID、顶边真人拖、改四条调用链。

## 使用场景

从 Finder 拖 PDF 到菜单栏图标或顶边：进架子、不跑 Agent、原件不动。再发给 Grok，拖出到桌面。

## 方案与关键决策

Ingest 认剪贴板味道；App 只把 `draggingPasteboard` 交进去。空板不报错（松手时可能已经没货）。

## 输入输出与依赖

输入：`NSPasteboard`。输出：`ClipboardPayload` → `Item`。依赖现有 `admit(urls:)` / `admitImageData` / `admitPlainText`。

## 文件 / 模块边界

- `macos/Packages/DropAgentIngest/Sources/PasteboardClipboard.swift`
- `macos/App/PlatformAdapters.swift`
- `macos/Check/main.swift`
- `macos/App/AppE2E.swift`
- `macos/App/AppDelegate.swift`：登记 draggedTypes

## 验收标准

1. Check：文件板 → `.files`；`https` URL → `.text` 且进货 kind 是 URL；空板 → `.empty`；图板 → `.image` 且 PNG 魔数，进货是图片。
2. `--e2e`：`admitPasteboard` 进 PDF，保持 idle，原件 Hash 不变，能拖到桌面，发给 Grok。
3. 图标和顶边的 `registerForDraggedTypes` 含 TIFF / JPEG / `public.image`。
4. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

顶边窗口命中仍要 Finder 亲手拖一次。
