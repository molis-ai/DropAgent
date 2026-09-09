# CLIP 卡片不要系统截断提示

## 背景与目标

悬停 CLIP 时，系统会给截断文字再弹一层提示，出现在卡片上方，顶到屏幕上沿，被别的窗口挡住。完整正文只应出现在面板左侧的悬停预览里。

## 当前行为与问题证据

卡片 `lineLimit` 会打开 AppKit `allowsExpansionToolTips`。提示画在卡片上方。文件行贴近菜单栏时，提示上半被 Cursor / 菜单栏挡住。

## 范围

- 文件卡关掉 expansion tooltip。
- 悬停预览按固定宽度、不限高度测量；超出 320pt 出现滚动，不再把多出来的正文裁在卡片后面。

## 非目标

- 不改卡片统一高度。
- 不恢复左右翻边。

## 验收标准

1. 悬停 CLIP：不出现贴在卡片正上方的系统黄/白提示条。
2. 左侧预览能看到换行后的全文（过长可滚）。
3. `--e2e` 悬停位置仍在面板左侧。

## 验证命令

```bash
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```
