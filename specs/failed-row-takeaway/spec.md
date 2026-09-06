# 失败但有产出时，架子行也标可拖出

## 背景目标

`02`：失败（已有产出）列表第二行是失败原因，AI 区仍可拿走。动作区已经走拿走。架子行只剩红「失败」+ 灰色原因，第一眼像没货。`01` 成功标准是菜单栏里出现新文件、能拖走。Hash 失败时货就是 `summary.md`。

## 当前行为与问题证据

`ItemRowView`：`.failed` 一律 `pill("失败")`，`metaLine` 用 `Palette.faint`。预览 `11b-failed-work`：动作区写「可拖出」，行上没有。无 output 的 `11c` 不该可拖出。

## 范围

- `.failed` 且 `output != nil`：红「失败」旁边加绿「可拖出」，原因用警告色。
- 无 output 的失败：仍只红「失败」，原因警告色。
- 完成态「可拖出」不变。
- 不改 Job、Hash、Pasteboard、动作区拿走逻辑。
- 预览 `11b` 行上能读到「失败」和「可拖出」；`11c` 行上没有「可拖出」。

## 非目标

- Developer ID。
- 不把无产出失败标成可拖出。
- 不改四条调用链。

## 使用场景

总结跑完、原件中途变了。人看架子：这条失败了，但还能拖走 `summary.md`。

## 方案与关键决策

状态词和拿走词并列，不把「失败」改成「可拖出」。原因从灰改成警告色，对齐 `02` 第二行是失败原因。

## 输入输出与依赖

输入：`Item.status` / `output` / `failureReason`。输出：行上胶囊和字色。

## 文件 / 模块边界

- `macos/App/PanelRootView.swift`
- `macos/App/PanelPreview.swift`（`11b` / `11c` 随渲染）
- 本 spec

## 验收标准

1. 预览 `11b-failed-work`：`summary.md` 行有「失败」和「可拖出」，原因仍是「原件中途变了」。
2. 预览 `11c-failed-retry`：`retry-fail.md` 行有「失败」，没有「可拖出」。
3. 预览 `06-result`：完成态仍只是绿「可拖出」。
4. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
```

## 假设与开放问题

窄行可能截断原因后半句；两个胶囊比丢掉「能拖」更符合第一眼。
