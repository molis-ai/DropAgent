# 失败但已有产出时，动作区先拿走

## 背景目标

`job.md`：原件 Hash 变了 → 条目 `failed`，**output 仍给用户看**。Pasteboard 对 failed + output 已经按结果文件拖出。Job 成功写完 `summary.md` 后只是校验失败：架子上的货是总结，不是坏掉的原件。

## 当前行为与问题证据

`Job.start` 在 mismatch 时仍写入 `output` / `title` / `kind`。`isDoneTakeaway` 只认 `.done`。预览 `11b-failed-work`：Hash 失败的 `summary.md` 动作区仍是六个 Recipe +「再点一个动作可以重试。」人刚跑完总结，点「动作」会以为没产出。无 output 的失败（Check 里 Agent 抛错）才该重试网格。

## 范围

- 选中项全部是 `.done`，或全部是 `.failed` 且 `output != nil`：动作区走拿走（「可拖出」+「打开结果」），不画六个 Recipe。
- 有失败原因：警告色写在拿走文案上方。
- 失败且有产出、有 Codex、条目还记着上次 Recipe：加一颗次要「再跑一次」，点了走现有 `chooseRecipe`。
- 无 output 的 failed：仍用 `failed-action-retry` 的网格。
- 预览 `11b-failed-work` 能读到「可拖出」「打开结果」和 Hash 那句；新增 `11c-failed-retry` 给无产出失败。
- `--e2e` 验 failed+output 走拿走、无 output 仍有重试句。
- 不改 Job 写盘、Hash、Pasteboard 载荷、四条调用链。

## 非目标

- Developer ID。
- 不把无产出的失败伪装成可拖出。
- 不改 `isolationShown`。

## 使用场景

总结跑完，原 PDF 被人改过。结果 Tab 能看 `summary.md`。点回「动作」：先拿走副本结果；真要再跑再点「再跑一次」。

## 方案与关键决策

拿走判定看「有没有可交的货」，不把 Hash 失败和 Agent 没写出文件混成一种失败。重试不再用六个按钮占住主路径。

## 输入输出与依赖

输入：选中项 `status` / `output` / `recipe` / `hasRecipe`。输出：动作区文案和按钮。依赖现有 `chooseRecipe`、`doneActionHint`。

## 文件 / 模块边界

- `macos/App/AppSession.swift`
- `macos/App/PanelRootView.swift`
- `macos/App/PanelPreview.swift`
- `macos/App/AppE2E.swift`
- `macos/Check/main.swift`（Hash 失败仍有 output）
- `specs/failed-action-retry/spec.md`（无产出预览改挂 `11c`）
- 本 spec

## 验收标准

1. 预览 `11b-failed-work`：动作 Tab；能读「原件中途变了」「可拖出」「打开结果」；没有「不能跑这些动作」；没有六个 Recipe 短名挤在主路径。
2. 预览 `11c-failed-retry`：能读「任务失败」和「再点一个动作可以重试」。
3. `--e2e`：failed + output → `isFailedOutputTakeaway`；failed 无 output → 该标志为假，重试句仍在。
4. Check：Hash mismatch 条目 `failed`，`output` 存在，title 为 `summary.md`。
5. 预览 `06b-done-work` 仍是拿走，没有失败黄字。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

无。
