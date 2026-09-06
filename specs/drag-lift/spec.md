# 拖出幽灵是标签加名字，不是整行截图

## 背景目标

`02`：整行可拖走，视觉是菜单栏小工具。现在 SwiftUI `onDrag` 默认把 400pt 整行截进拖影，挡目标窗口，也不像 Yoink / Dropover。原型 `.row.dragging-out` 是缩小的那一条，不是整块面板。

## 当前行为与问题证据

`RowDrag` / `DragOutButton` 只有 `onDrag { itemProvider }`，没有自定义 `preview`。预览 `03-idle` 看不出拖影，真机拖才暴露。

## 范围

- 架子行、结果「拖出」：拖影是标签 + 标题的小芯片（炭灰、6pt 圆角、1px 边、带偏移的投影）。
- 运行中仍不能拖。
- 标签栏高度对齐原型 24pt（现在 28）。
- 不改 Pasteboard UTI、一次一条、默认复制。

## 非目标

- Developer ID、真人拖到 Finder 的落地（已有 CLIP/URL/文件夹 Check）。
- 不把源行做成半透明（系统不给拖结束回调，硬做会卡住状态）。

## 使用场景

从架子拖 `summary.md` 到桌面：手上跟的是 `MD summary.md` 小芯片，不是半个面板。

## 方案与关键决策

`onDrag(provider) { DragLiftChip }`。芯片只展示，货仍走 `PasteboardService.itemProvider`。

## 输入输出与依赖

输入：Item。输出：拖影视图。依赖现有 Pasteboard。

## 文件 / 模块边界

- `macos/App/PanelRootView.swift`
- 预览对照即可；Check 不 import App。

## 验收标准

1. 预览 `03-idle` / `06-result`：标签栏仍是 动作 / 终端 / 结果，不挤破头。
2. 代码：`RowDrag` 与 `DragOutButton` 使用自定义 preview，不是默认整行。
3. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
```

## 假设与开放问题

无。
