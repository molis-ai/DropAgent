# 确认 Recipe 时隔离档用 Agent 的原话，不许说成 Safe Copy

## 背景目标

`01` 要求执行前写清是哪一档隔离。`agent.md`：只有能证明工作区限制，才写 Workspace Sandbox；否则写「未确认工作区限制，仍在副本目录跑」。内核 `isolationCopy` 已经是这两句。确认权限条把非 workspace 一律写成 **Safe Copy**。没探测到沙箱时，人会以为是 01 表里给 Claude 的那一档。

## 当前行为与问题证据

`PanelRootView.facts`：`isolation == .workspace ? "Workspace Sandbox" : "Safe Copy"`。Check 已验 `isolationCopy(.unknown) == "未确认工作区限制，仍在副本目录跑"`，面板没用它。预览 `04-confirm` 只覆盖本机已确认 workspace 的情况。

## 范围

- 确认权限条「隔离」一行：有 Codex 时用 `Agent.isolationCopy(for: recipePresence)`；没有 Codex 仍写「无 Codex」。
- 行高随文案换行，不裁成 26pt 把后半句切掉。
- 预览 `04b-unconfirmed`：把 `recipePresence` 设成 Codex + `.unknown`，画面上是未确认那句，不是 Safe Copy。
- `--e2e` 断言 unknown / workspace 两档文案。
- 不改四条调用链。不把 `IsolationShown` 扩成第五档（条目上这个字段目前没有画出来）。

## 非目标

- Developer ID。
- 不改 Recipe 只跑 Codex。
- 不把 TUI 说成 Workspace Sandbox。

## 使用场景

本机有 `codex` 但 `--help` 证明不了工作区沙箱：点「总结」后，隔离行是「未确认工作区限制，仍在副本目录跑」，不是 Safe Copy。

## 方案与关键决策

UI 只转述 `isolationCopy`，不在 View 里映射档名。Safe Copy 仍只出现在 isolationCopy 不会产出它的路径上——当前 Codex unknown 不是 Safe Copy。

## 输入输出与依赖

输入：`recipePresence`。输出：权限条第四行。依赖现有 `AgentService.isolationCopy`。

## 文件 / 模块边界

- `macos/App/AppSession.swift`
- `macos/App/PanelRootView.swift`
- `macos/App/PanelPreview.swift`
- `macos/App/AppE2E.swift`
- 本 spec

## 验收标准

1. `--e2e`：Codex + unknown → 隔离事实含「未确认工作区限制」，不含「Safe Copy」；workspace → 含「Workspace Sandbox」，不含「完全看不到」。
2. 预览 `04b-unconfirmed` 能读到「未确认工作区限制」。
3. 预览 `04-confirm` 在本机 workspace 时仍能读到 Workspace Sandbox。
4. Check 全绿；`isolationCopy` 原句不变。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

条目上的 `isolationShown` 按 IsolationGrade 记录；Codex unknown 记 `unconfirmed`，结果页可回看。见 `specs/isolation-shown-record`。
