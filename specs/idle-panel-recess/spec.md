# 闲时面板：淡化并让开

## 背景与目标

面板开着时一直浮在菜单栏那一层，去别的 App 干活会又抢眼又挡住点击和阅读。人离开后既要变淡，又要沉到普通窗口后面。点还露着的面板，或把文件拖进面板原来那块区域，再回到最前。

## 当前行为

`DropAgentPanel`：`level = .statusBar`，`hidesOnDeactivate = false`，失焦后仍不透明、仍盖住别的窗口。图标和开合快捷键在 `isVisible` 时一律关掉。

## 范围与非目标

做：窗口壳的闲时态、唤醒、图标/开合快捷键。  
不做：点透水印、一拖文件就整块弹出、自动关面板、改进货 / Job / TUI、设置开关。

## 行为

- **闲时**（可见、不是 key、鼠标不在面板上、不是从面板往外拖、不是正在系统拖、不是诊断启动、不是正在选文件）：约 0.7 秒后透明度 0.72，层级降到 `.normal`。
- **醒**：点还露着的面板（第一下也算正常点击）；外部拖靠近面板矩形外扩 64pt 即抬到菜单栏层（12pt 内算落到面板上）；图标或开合快捷键（闲时是唤醒，不是关）；`showPanel`。
- 系统拖进行中不沉到后面，避免落点穿到后面的编辑器。拖去 Mail / 桌面：还没靠近面板时继续躲着。从面板拖出：中途不淡、不沉。Esc / 叉 / 最小化仍是关掉。
- 靠近面板时轮盘先收掉，避免空洞把拖让给后面的窗口。
- `--preview` / `--e2e` / `--capture`、减少动态效果：不播动画；诊断启动不进入闲时。

## 文件

`macos/App/PanelIdle.swift`、`AppDelegate+Panel.swift`、`AppDelegate.swift`、`EdgeDropController.swift`、`PanelChrome.swift`、`AppE2E.swift`、`design/modules/app-shell.md`、`02-prototype-design.md`。

## 验收

1. `PanelIdle.toggle`：隐藏→开；闲时→醒；亮着→关。
2. `shouldRecess`：失焦且鼠标在外才闲时；key / 鼠标在内 / 往外拖 / 正在系统拖 / 诊断 / 正在选文件不闲时。
3. 拖点在面板框外扩 12pt 内算落到面板；外扩 64pt 算靠近、要唤醒。
4. `applyRecess` 后 alpha 0.72、level normal；`applyActive` 后 alpha 1、level statusBar。
5. `swift run DropAgentCheck`；`swift build --product DropAgent`。
