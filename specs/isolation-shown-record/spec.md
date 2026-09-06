# 条目记下的隔离档必须和探测结果一致

## 背景目标

`01`：界面必须写清当前任务实际是哪一档隔离。确认条已经转述 `isolationCopy`。`isolation-fact` 记下：条目 `isolationShown` 仍把 Codex `.unknown` 写成 `safeCopy`。`03` 说这个字段是「当前对外说的档」。跑完之后确认条没了，结果页也看不到档位；`shelf.json` 里还是一句假的 Safe Copy。

## 当前行为与问题证据

`JobService.start`：`presence.isolation == .workspace ? .workspace : .safeCopy`。Codex 证不了工作区时 IsolationGrade 是 `.unknown`，却被记成 Safe Copy（01 表里给 Claude 的那档）。Check 不验 `isolationShown`。预览 `06-result` 不写这个字段，结果页没有档位。

## 范围

- `IsolationShown` 增加 `unconfirmed`。Job 按 IsolationGrade 记：workspace → workspace，unknown → unconfirmed，tui → tui，none → none。不再把 unknown 写成 safeCopy。
- `safeCopy` 仍留在枚举（01 词汇 / 以后 Claude Recipe），Codex Job 第一版不会写入。
- 结果页对 recipe 产出（workspace / unconfirmed / safeCopy）用同一句人话回看档位；TUI / none 不画。
- 确认条仍读 `recipePresence`，不改。
- Check：workspace Job 记 workspace；unknown Job 记 unconfirmed，不是 safeCopy。文案与 `isolationCopy` 对齐。
- 预览 `06-result` 能读到 Workspace Sandbox；新增 `06c-unconfirmed-result` 是未确认那句，不是 Safe Copy。
- `--e2e` 验结果页两档文案。
- 不改四条调用链、不改 `execArguments`。

## 非目标

- Developer ID。
- 不把 TUI 说成 Workspace Sandbox。
- 不迁移旧 `shelf.json` 里已经写成 safeCopy 的条目。

## 使用场景

本机 Codex 证不了工作区：确认时是未确认那句；跑完点「结果」仍是这句，架子记录也不是 Safe Copy。能证明 workspace 时，结果页仍写 Workspace Sandbox。

## 方案与关键决策

条目只存档名，不存整句。对外句子仍以 Agent 的 isolationCopy 为准，IsolationShown 上的人话必须逐字相同。结果页回看，避免确认过后档位消失。

## 输入输出与依赖

输入：`AgentPresence.isolation`。输出：Item.isolationShown；结果 Tab 一行。依赖现有 `isolationCopy`。

## 文件 / 模块边界

- `macos/Packages/DropAgentShelf/Sources/Item.swift`
- `macos/Packages/DropAgentJob/Sources/JobService.swift`
- `macos/Check/main.swift`
- `macos/App/AppSession.swift`
- `macos/App/PanelRootView.swift`
- `macos/App/PanelPreview.swift`
- `macos/App/AppE2E.swift`
- `03-tech-architecture.md`
- `specs/isolation-fact/spec.md`（划掉 later）
- 本 spec

## 验收标准

1. Check：workspace 总结后 `isolationShown == .workspace`。
2. Check：unknown 总结后 `isolationShown == .unconfirmed`，不是 `.safeCopy`；`spokenFact` 与 `isolationCopy(.unknown)` 相同。
3. 预览 `06-result` 能读到 Workspace Sandbox；`06c-unconfirmed-result` 能读到「未确认工作区限制」，不含 Safe Copy。
4. `--e2e`：结果条目 unconfirmed / workspace 两档文案同上。
5. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

无。
