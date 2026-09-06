# 图片标签按真实格式；面板拖入接住 HEIC

## 背景目标

`01` 接收 png/jpg/webp/gif/heic。架子上所有图都打 `PNG`。菜单栏图标已登记 HEIC，面板 SwiftUI `onDrop` 和 `DropProviders.imageData` 没列 HEIC / GIF / WebP。相册拖一张 HEIC 到列表可能进不来。

## 当前行为与问题证据

- `ItemKind.tag` 对 `.image` 固定 `"PNG"`；`displayTag` 原样用它。
- `PanelRootView` 列表 / AI 区 `onDrop(of: [.fileURL, .url, .utf8PlainText, .image])`。
- `DropProviders.imageData` 只试 png / jpeg / tiff / image。

## 范围

- 图片条标签看文件名扩展：JPG / HEIC / GIF / WEBP / TIFF / PNG。剪贴板写成 png 的仍是 PNG。
- 面板 `onDrop` 与图标共用同一组 UTI（含 heic / jpeg / gif / webP）。
- `DropProviders.imageData` 同样尝试这些类型；能解成位图就仍落成 Inbox png。
- 从 Finder 拖 `.heic` 文件仍走 file URL，kind 是 image，标签 HEIC。

## 非目标

- 不做 HEIC 阅读器。不改四条调用链。Developer ID。

## 使用场景

桌面 `shot.jpg` 进架子，标签是 JPG。相册 HEIC 拖到面板列表，进得来。

## 方案与关键决策

`displayTag` 对 `.image` 读 `parts` 文件名。`IncomingDrop.contentTypes` 单一来源。

## 输入输出与依赖

输入：带扩展名的图片文件、HEIC item provider。输出：Item.kind / displayTag、AdmitResult。

## 文件 / 模块边界

- `macos/Packages/DropAgentShelf/Sources/Item.swift`
- `macos/Packages/DropAgentIngest/Sources/DropProviders.swift`
- `macos/App/PlatformAdapters.swift`
- `macos/App/PanelRootView.swift`
- `macos/Check/main.swift`

## 验收标准

1. Check：`shot.jpg` 进货 kind 是 image，`displayTag` 是 `JPG`。
2. Check：`photo.heic` 进货 `displayTag` 是 `HEIC`。
3. Check：只登记 HEIC 数据的 item provider 能 `admitProviders` 进一条 image。
4. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
```

## 假设与开放问题

内存里的 HEIC 若能转成位图，Inbox 仍写成 `clipboard.png`，标签 PNG。文件拖入保留原扩展名。
