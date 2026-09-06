# 面板开着时，系统拖拽先画出上下投放区

## 背景目标

`02`：拖入时上下分区，上加入架子，下发给当前 TUI。原型在整桌开始拖时就亮出两区提示（`.desk.dragging`）。现在 SwiftUI `onDrop(isTargeted:)` 只在鼠标压进某一区才出现蓝罩，开着面板从 Finder 拖过来时，人要猜该松在哪。

## 当前行为与问题证据

`listHot` / `aiHot` 只绑 `onDrop` 命中。下区罩曾留 48pt 底边，预览 `01-drag` / `03-drag` 会露出半截输入框。

## 范围

- 系统拖拽剪贴板有货、且拖拽不是从本面板里的行开始：面板同时现出「加入架子」和「发给 {TUI}」（无 TUI 时下区仍写「加入架子」）。
- 下区罩盖住整个 AI 区（含输入行和脚注），不再留底边缺口。
- 鼠标进入某一区：该区用现有命中态（更实的墨），另一区保持提示。
- 从架子行往外拖：不亮投放罩，避免挡住拖出。
- 松手或剪贴板空了：罩立刻收。Reduce Motion / `--preview` / `--e2e` 仍可切到提示态，只是不做位移动画。
- 不改四条调用链、不改顶边几何、不改 UTI。

## 非目标

- Developer ID。
- 不把桌面 CLIP 芯片做成正式浮层。
- 不解析 TUI。

## 使用场景

架子上已有文件，面板开着。从 Finder 再拖一份 PDF：还没松手就能看见上半「加入架子」、下半「发给 Grok」。拖到下半松手，材料进终端。

## 方案与关键决策

`AppSession.systemDragActive`。全局 `leftMouseDragged` 在剪贴板有货、且鼠标当时不在面板里时置真（Finder 拖从外面开始）；面板内起拖（行 `onDrag`）不置真。`leftMouseUp` 或剪贴板空了置假。

提示态比命中态淡一档，仍是墨色，不是第二种强调色。

## 输入输出与依赖

输入：拖拽剪贴板、鼠标位置、面板 frame。输出：两区 overlay。依赖现有 `IncomingDrop` / `EdgePlacement.dragPasteboardHasPayload`。

## 文件 / 模块边界

- `macos/App/AppSession.swift`
- `macos/App/AppDelegate.swift`
- `macos/App/PanelRootView.swift`
- `macos/App/PanelPreview.swift`
- `macos/App/AppE2E.swift`
- 本 spec

## 验收标准

1. 预览 `01-drag`：空架子时上下两区都能读到投放字；下区罩盖住输入行，不再露出半截输入框；`01-empty` 仍无投放罩。
2. 预览 `03-drag`：有 PDF 时上区是「加入架子」，下区是「发给」当前终端名，同样盖住输入行。
3. `--e2e` 能写出 `e2e-drag-empty` 快照；其余 e2e 仍过。
4. Check 全绿。四条调用链不变。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

全局监视在本机普通权限下能收到 Finder 拖拽；若以后要 Input Monitoring，菜单栏图标和面板 `onDrop` 仍是进货口。
