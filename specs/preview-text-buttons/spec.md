# 预览顶栏：文字按钮 + 纸面细边

状态：已实现。完成等级 3（功能可用）。唯一需求书。依据本会话「预览页右上角的编辑按钮不太明显，改成文字按钮并带边框」。

## 背景目标

内容台右上角「编辑副本」现在是 24pt 无边框铅笔图标，休息态几乎看不出能点。要改成能读出动作名、带纸面细边的文字按钮。

## 当前行为与问题证据

- `ContentStage` 顶栏右侧：`Image(systemName: square.and.pencil / checkmark)` + `IconButtonStyle(size: 24)`。文案只在 help / VoiceOver。
- 结果工具条、剪贴板预览顶栏已是文字，但 `QuietButtonStyle(subtle: true)` 走 `.quiet`，休息态无描边。

## 范围与非目标

范围：内容台顶栏编辑入口；结果预览上方「对照原文 / 复制文件 / 用作材料」；剪贴板预览顶栏「复制 / 加入材料」。标识符、点击语义、禁用条件不变。

非目标：不改侧栏行尾图标、底栏 Recipe 芯片、内核编辑契约、新动作。

## 使用场景

打开一份可编文字材料，右上角看见带细边的「编辑副本」。点进去变成「完成编辑」。看结果或剪贴板时，顶栏动作同样是带边的文字按钮。

## 方案与关键决策

1. 编辑入口用 `Text("编辑副本" / "完成编辑")` + `QuietButtonStyle()`（`.paper`：浅底 + `Palette.line` 1pt 圆角边）。不再用仅图标。
2. 结果工具条、剪贴板顶栏去掉 `subtle: true`，同一套纸面细边。
3. `stage-edit` / `compare-result` / `take-copy` / `import-result` / `clip-copy` / `clip-admit` 保留。

## 文件 / 模块边界

- `macos/App/ContentStage.swift`
- `macos/App/WorkbenchDetail.swift`
- `DESIGN.md`、`design/modules/app-shell.md`

## 验收

1. 可编材料预览顶栏右侧是带边框的「编辑副本」文字；编辑中为「完成编辑」。`stage-edit` 仍可点，行为与现在相同。
2. 结果与剪贴板预览顶栏次要动作休息态有纸面细边。
3. `swift run DropAgentCheck` 与 `swift build --product DropAgent` 通过。

## 验证

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e --workbench-only
```

## 假设与开放问题

「什么的」按同一预览顶栏处理结果和剪贴板动作；侧栏行尾不改。
