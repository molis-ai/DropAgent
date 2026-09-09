# 悬停预览：离开文件卡后暂留两秒

## 背景与目标

预览贴在整块面板左侧，不跟文件卡。离开卡片后只留约 280ms，从文件移到预览要横穿面板，中途预览已经关掉。一骏要求：预览先停几秒，人来得及移过去。

完成等级：功能可用。

## 当前行为与问题

- `HoverPreviewWindow.hideDelayNanos` 为 280ms，和 8pt 透明桥只够跨过纸面空隙。
- 文件在横向架子上。去左侧预览要先离开卡片，再走过栏头、别的卡或动作区。
- 面板闲时淡化会立刻 `hideHover()`，绕面板外侧走近预览时也会被清掉。

本 spec 覆盖 `specs/hover-stay-scroll/spec.md` 里「离开卡片后延迟约 280ms 再关」。指针在预览卡内不关、过长可滚，仍以那份为准。

## 范围

- 离开文件卡或结果卡后，预览再留约 2 秒。这段时间里移进预览则取消关闭，预览接着显示。
- 指针离开预览、也不在对应卡片上：2 秒后关掉。
- 面板闲时淡化不立刻关预览；预览走自己的 2 秒计时。
- 关面板、开设置、打开文件、进货：立刻关掉，不等这 2 秒。

## 非目标

- 不改预览位置、正文渲染、滚动。
- 不把预览改成完整结果页。
- 不从卡片画安全三角形。

## 方案

- `hideDelayNanos` 改为 2 秒。
- `hideHover(of:)` 仍走延迟关闭；无 id 的 `hideHover()` 仍立刻关。
- `recessPanelIfNeeded` 不再调用 `hideHover()`。

## 验收

1. 悬停出预览后离开文件卡：280ms 时预览还在，约 2 秒后才关。
2. 这两秒内把指针移进预览：预览还在，可滚动。
3. 关面板或开设置：预览立刻关掉。
4. 面板闲时淡化：预览不跟着立刻消失。
5. `swift run DropAgentCheck` 与 `--e2e` 通过。

## 验证

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```
