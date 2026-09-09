# 悬停预览放在整个面板左侧

## 背景与目标

悬停预览跟着卡片走，出现在卡片下方，容易叠在动作栏或结果区上，位置发飘。一骏要求：出现在整个面板左侧。

完成等级：功能可用。

## 当前行为

`HoverPreviewWindow.show` 用卡片屏幕坐标：`x = card.minX`，`y = card.minY - 8 - height`。横版文件卡下面就是面板内部。

## 范围

- 预览贴在 DropAgent 面板（可见纸面）左侧，顶对齐。
- 左侧不够出屏幕时夹在屏幕内，不翻到右侧。见 `specs/hover-pin-left/spec.md`。
- 仍在窗外独立层，不撑布局。预览卡接收指针以便停留和滚动，见 `specs/hover-stay-scroll/spec.md`。
- 卡片短摘要位置不改。

## 非目标

- 不改正文可读渲染。
- 不挡文件卡本身。指针在预览卡内的停留与滚动见 `specs/hover-stay-scroll/spec.md`。

## 方案

- 用面板窗口坐标（减去阴影垫）当锚，不跟卡片。
- `HoverPlacement.frame` 纯函数：始终左侧，再夹进屏幕。
- 原型同样贴在 `#panel` 左侧。

## 验收

1. 悬停文件或结果：预览在面板左侧，不盖住卡片。
2. 面板贴屏幕左缘时：预览仍在左侧，不翻到右侧。
3. `swift run DropAgentCheck` 与 `--e2e` 通过。

## 验证

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```
