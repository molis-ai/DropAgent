# 面板四周不要一圈脏阴影

## 背景与目标

面板周围有一圈颜色带着阴影，看起来像描边光晕，不是落在桌面上的投影。

完成等级：功能可用。

## 当前行为与问题

- 文件架和对话卡：`shadow(opacity 0.34, radius 24, y 14)`。
- 窗口只留 `dockShadowPad = 22`，阴影被裁成贴边的一圈。
- 文件架还有 1pt `Palette.line` 描边，叠在裁切阴影上更像色环。
- `PaperHostView` 未声明非不透明，22pt 垫可能衬出一块底色。

## 范围

- 面板纸面投影、窗口透明垫、描边。
- 悬停定位仍按纸面外沿（`dockShadowPad`）。

## 非目标

- 不改闲时淡出、选中描边、文件卡自己的轻投影。

## 方案

- 去掉面板外圈描边。
- 投影改成更淡、能在垫里散开；`dockShadowPad` 大于模糊半径。
- `PaperHostView` 透明，垫里露出桌面。

## 验收

1. 面板四周是淡下去的投影，不是一圈实色。
2. 垫是透明的，不是第二块矩形底。
3. `swift run DropAgentCheck` 与 `--e2e` 通过。

## 验证

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```
