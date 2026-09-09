# 悬停预览固定在面板左侧

## 背景与目标

预览会在左、右两侧来回出现。人悬停文件时期望位置稳定。固定贴在整个面板左侧；左侧不够出屏幕时夹在屏幕内，不翻到右侧。

## 当前行为与问题证据

`HoverPlacement.frame` 优先左侧，`x < screen.minX + 8` 时改到 `paper.maxX + gap`。面板靠近左缘，或左右都紧时，同一次使用会看到预览换边。`specs/hover-left-of-panel/spec.md` 曾把翻到右侧写成验收。

## 范围

- 预览始终按面板左侧锚点放置。
- 会出屏幕时只水平夹进可见区域，不改到面板右侧。
- 桥接空隙仍在预览和纸面之间（预览在左，桥在右）。
- 更新 `hover-left-of-panel`：不再验收翻边。

## 非目标

- 不改悬停停留、滚动、正文渲染。
- 不做可配置的左/右开关。

## 验收标准

1. 面板中间：预览贴在纸面左侧。
2. 面板贴屏幕左缘：预览仍在面板中线左侧，不会出现在纸面右侧。
3. `--e2e` `verifyHoverPlacement` 覆盖以上两点。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```
