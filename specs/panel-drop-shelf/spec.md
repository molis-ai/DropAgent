# 拖到整块面板即加入架子

状态：已实现。完成等级 3。唯一需求书。依据本会话「拖到 panel 释放没反应；只要拖进整块面板就显示加入架子，释放加入」。补充：左侧目录松手同样没接住。

## 背景目标

工作台改成左右布局后，从 Finder 把文件拖进面板松手没有进架子。人要把文件放到当前打开的工作台，不必对准左侧 213pt 目录，也不该猜投放区。

## 当前行为与问题证据

- `onDrop` 只挂在左侧目录，右侧预览不是投放目标。现场补充：左侧松手同样没进货，SwiftUI destination 整块都没接住 Finder 跨进程拖放。
- `EdgeDropController` 在面板上松手走 `panelTakesDrop` 后只 `finishExternalDrag`，自己不进货。
- 外部拖从面板外开始才置 `systemDragActive`；从面板矩形内开始的 Finder 拖不会亮罩。
- 对话区仍单独接「发给终端」，和「整块面板加入架子」冲突。

## 范围与非目标

范围：整块主面板（含顶栏、目录、预览、指令）在外部文件拖入时显示「加入材料」；松手走现有 Ingest 加入副本。从架子行拖出、轮盘已拥有的投放、敏感剪贴板过滤不变。发给终端仍走轮盘「发给终端」。投放罩半透明，不盖死底下目录。已进货的同一次拖，后续 `performDragOperation` 仍返回 true，避免 Finder 回弹。

非目标：不改轮盘六瓣动作；不改顶边条；不改复制文件自动上架；不把对话区重新做成投放分区。

## 使用场景

面板开着。从 Finder 拖一份 PDF 到预览、顶栏或指令任意处：整块面板出现「加入材料」。松手后 PDF 副本进材料，原件不动。拖到轮盘瓣上仍按轮盘动作。

## 方案与关键决策

1. 投放罩挂到 `PanelRootView`，覆盖可见纸面。指针进入面板且这是外部拖（不是架子拖出）时显示；离开或结束即收。
2. 主路径不靠 SwiftUI `onDrop`（左侧已经证明 Finder 跨进程进不了）。面板 hosting view 注册 AppKit 拖放并 `performDragOperation` → `admitPasteboard`。松手时若 destination 没回调，用轮盘同一套 live/snapshot 在 `EdgeDropController` 进货。同一次拖用粘贴板 changeCount 只进一次。
3. 一次拖只进货一次（`consumeExternalDrop`）。架子内部拖出不进货、不亮罩。
4. 去掉侧栏和对话区各自的投放罩与 drop。外部拖进入面板矩形即可置 `systemDragActive`，不再要求先在面板外。

## 文件 / 模块边界

- `macos/App/PanelRootView.swift`、`WorkbenchSidebar.swift`、`AIPane.swift`
- `macos/App/PanelChrome.swift`、`AppDelegate+Panel.swift`
- `macos/App/EdgeDropController.swift`、`AppSession.swift`、`AppSession+Admit.swift`
- `macos/App/WheelE2E.swift`
- `DESIGN.md`、`02-prototype-design.md`、`design/modules/app-shell.md`

## 验收标准

1. 外部文件拖到面板任意可见处，整块面板显示「加入材料」；架子行向外拖不显示。通过：`WheelE2E` 左侧坐标亮罩；架子拖出不亮罩。
2. 松手加入副本，原件不变；同一拖不会进两次。通过：左侧 `mouseUp` 进货一次；AppKit `performDragOperation` 后再 `mouseUp` 仍只有一份。
3. 轮盘已拥有的投放不被面板抢走；从面板内开始的拖不呼出轮盘。通过：原 overlapping / direct panel 用例。
4. `cd macos && swift build --product DropAgent` 通过。
5. `cd macos && swift run DropAgentCheck` 未运行本项相关失败。现有 `recipePresence(.cursor)` 失败与本项无关。
6. `DROPAGENT_ROOT=/tmp/dropagent-panel-drop macos/.build/debug/DropAgent --e2e --wheel-only` 通过（含 left panel drop）。工作台 `--workbench-only` 通过。

## 假设

Finder 仍可能不发 `leftMouseUp`；已有拖拽 watchdog 会收尾。面板投影留白也算面板矩形，松在阴影上同样加入。
