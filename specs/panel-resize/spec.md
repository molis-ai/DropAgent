# 面板可调大小

用户习惯从边角拉窗口。当前工作台故意固定外窗，边角拉不动。本次允许人调整大小并记住宽高；确认、运行、对话仍不得自己改变外窗。

完成等级：功能可用。

## 背景

v0.2.0 把上下堆叠改成左右工作台后，外窗锁死，避免确认 / 运行 / 对话把高度和按钮位置带着跳。`specs/panel-move` 加拖动时把「不拉大小」列为非目标。

固定外窗解决的是**程序不要自己改尺寸**。人拉一把符合桌面软件习惯，和「状态变化不伸缩」不冲突。

无边框面板四周有 36pt 投影留白。系统 `.resizable` 命中的是窗外沿，人抓到的是纸面边。所以不挂系统标题栏、不加红绿灯，在纸面左右边和下边做拖动手柄。

## 范围

1. 拖纸面左边、右边、下边和左下 / 右下角，窗口跟着变。顶栏仍只负责挪位置。无系统标题栏。
2. 默认仍是 1160 × 640pt（含投影）。最小约 800 × 480，最大不超过当前可见屏幕。窄到 800pt 时对照原文仍按现有上下对照。
3. 松手后把宽高和位置一并写入偏好。收起、再开、重启沿用。没拉过仍用默认尺寸。程序 `setFrame`、收起动画、确认 / 运行 / 对话不得改尺寸或抢写偏好。
4. 改动限于面板窗口、拖动手柄、定位与偏好；不改进货、Recipe、原件保护。

## 非目标

- 不上系统标题栏或红绿灯。
- 不让任务状态改变外窗。
- 不按桌面分别记尺寸。
- 不改侧栏 213pt 为可拖分栏（左右分的是窗口，不是目录宽）。

## 方案

- `PanelResize` 按锚边计算新 frame，再 `PanelPlacement.clamp`。
- 纸面左右和下边覆盖 8pt 手柄，角 16pt；命中转换成屏幕坐标后改 `DropAgentPanel` frame。
- 偏好增加 `panelWidth` / `panelHeight`。只在用户松手后与 `panelX` / `panelTop` 一起写。
- `LivePanelChrome.styleMask` 仍是 borderless，不含 `.resizable` / `.titled`。

## 验收

1. 抓右下角或下边、左右边，窗口变大变小；顶栏拖动仍只挪位置。
2. 拉到最小后不再缩；拉出屏幕被夹回可见区。
3. 松手前偏好不更新；松手后关再开保持宽高和位置。
4. 点总结 / 提取 / 对话，外窗尺寸不变。
5. 仍无标题栏；`styleMask` 不含 titled、resizable。

## 验证

```bash
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-panel-resize macos/.build/debug/DropAgent --e2e --panel-only
DROPAGENT_ROOT=/tmp/dropagent-panel-resize-ui macos/.build/debug/DropAgent --e2e --ui-only
```
