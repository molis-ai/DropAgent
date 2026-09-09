# 多选拖出应交出所选项，不是只交一行

## 背景与目标

架子已经能多选。人勾了几份文件再拖到桌面，期望落下同样多份。现在 `onDrag` 只带被抓住的那一行，多选被丢掉。

## 当前行为与问题证据

- `RowDrag` / `DragOutButton` 调用 `PasteboardService.itemProvider(for: item)`，一个 `NSItemProvider` 对应一条。
- `copySelected()` 只用 `selectedItems.first`。
- 产品文案仍写「一次拖一条」（`01` 第 11 节、`02` 第 6 节、设置「拖出去」）。

## 范围

- 拖的那条在当前选择里，且选择里可拖出的多于一条：拖出 / 复制交这些条的文件（运行中的除外）。
- 拖的那条不在选择里，或只选了一条：仍只交这一条，单条仍带原来的文件 / 文字 / 图 / 链接。
- Finder / 桌面应能读到多条文件路径（`NSFilenamesPboardType` + 多条 file URL）。
- 设置说明、`01` / `02` / 模块说明改成多选一次拖出所选项。复制仍不是挪走。
- 拖影：一条时仍是标签 + 标题；多条时同一芯片加「及另外 N 项」。

## 非目标

- 结果栏多选。
- Shift 连续选。
- 为某一家 App 做插件。
- 真人拖到微信 / 上传框的全覆盖；Check 证明 pasteboard 上有多条文件。

## 使用场景

多选两份 Markdown，从架子拖到桌面：落下两个文件，架子上原件还在。

## 方案与关键决策

1. `PasteboardService.exportGroup(starting:selection:)` 决定交哪些条。
2. 多条只交每条的 `fileURLs`（网站条仍是那个抓页文件夹）。没有文件的纯链接在「里面有文件」的多选里不占位。
3. SwiftUI 仍用 `onDrag`（和列表滚动兼容）。Provider 注册 `NSFilenamesPboardType`；松手前再往 `NSPasteboard.drag` 补齐多条 file URL，避免系统只留下第一个 Provider。

## 输入输出与依赖

输入：被拖的 Item + 当前选择。输出：一条或多条文件 URL，复制不是删除。依赖现有 `representation(for:)`。

## 文件 / 模块边界

- `macos/Packages/DropAgentPasteboard/Sources/PasteboardService.swift`
- `macos/App/ItemRowView.swift`、`AppSession+Export.swift`、`ShelfColumn.swift`、`SettingsGuideCopy.swift`
- `macos/Check/main.swift`
- `01-requirements.md`、`02-prototype-design.md`、`03-tech-architecture.md`、`design/modules/pasteboard.md`、`PRODUCT.md`、`README.md`、`prototype/index.html`

## 验收标准

1. Check：`exportGroup` 在「拖的是选中之一」时返回全部可拖出选择；拖未选中的行只返回该行。
2. Check：两条文稿 `copy` 后 pasteboard 有两个 file URL；原文件仍在。
3. Check：多条 `itemProvider` 能读出两条路径（filenames 或 file URL）。
4. Check：单条文稿拖出仍带 file + utf8 正文。
5. 设置「拖出去」不再写「一次拖一条」，仍写复制不是挪走。
6. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
```

## 假设与开放问题

SwiftUI `onDrag` 可能覆盖 drag pasteboard。用 filenames + 主线程补写 file URL 兜底；若某目标只吃第一个 Provider，至少桌面 / Finder 应能接到 filenames 数组。
