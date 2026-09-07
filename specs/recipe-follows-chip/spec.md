# 快捷操作跟芯片走

## 背景目标

点翻译 / 总结 / 抽取等快捷动作，必须用**当前芯片对应的那家 CLI**，在任务副本目录里按该动作的 Prompt 做事，把结果写回约定 `output/`，再收回架子。不要永远绑 Codex，也不要把 Recipe Prompt 拼进 TUI 对话框完事。

## 当前行为与问题证据

- `AgentService.recipePresence` 只探测 Codex；`tuiPresence` 才跟芯片。
- `Job.start` `guard case .codex`；`AgentService.run` 只走 `codex exec`。
- 确认区 `HotKeyCopy.recipeActorLine`：「Codex 在副本里跑，不是 Grok 终端。」芯片是 Grok 时这就是分裂。
- 隔离文案把 Grok / Claude / Gemini 一律说成「在终端执行」，即使这次其实在副本里跑。

## 范围

- 改 `01` / `02` / `03` 和 `design/modules/agent.md`、`job.md`、`ai-pane.md`：删掉「六个 Recipe 第一版只保证 Codex」。
- Recipe 跟芯片：`recipePresence` = 当前 TUI 引擎，且该引擎的 `--help` 能证明有无界面 / 可收口 Job 入口。
- 仍走调用链 B：`Job.start` → `Agent.run(cwd: work/)`。不走链 C `TUI.send`。
- 没装对应 CLI，或没有可收口入口：动作禁用，人话说清楚；有 TUI 仍可发送。
- 不能解析 TUI 画面、不能模拟键盘点终端菜单；不能假装 Job 已完成。
- 隔离文案跟**谁在跑**：只有该 CLI 能证明 Workspace 才写 Workspace；否则未确认 / Safe Copy 工作流承诺，不把 Codex 的 Workspace 套到别人头上。
- 确认 / 运行文案跟芯片同一家，不再写「芯片是 Grok、实际是 Codex」。
- 原型、左右分栏、最小化、多选入口一起对齐。

## 非目标

- 不改四条调用链的进货边界。
- 不覆盖用户原文件。
- 不 `commit` / `push`。
- 不加 `--always-approve` / `bypassPermissions` / `--dangerously-skip-permissions`。
- 不为没有 `--help` 证据的 flag 发明无界面入口。

## 使用场景

1. 芯片是 Grok，且 `grok --help` 有 `--prompt-file` / `--single`：点总结 → Grok 在 `work/` 里跑 → `output/summary.md` 回架子。确认区写 Grok 在任务副本里跑。
2. 芯片是 Claude，且有 `-p/--print`：动作走 Claude print，不是 Codex。
3. 芯片是某家已装 TUI，但 `--help` 没有可收口入口：动作禁用，说明没有无界面执行入口；发送仍可用。
4. 没装芯片对应 CLI：动作禁用并说清楚。
5. 只有能证明 workspace-write 的 Codex 才写 Workspace Sandbox；Grok 有 `--sandbox` 但 help 未列出 workspace-write 时写未确认，不写 Workspace。

## 方案与关键决策

- 入口以本机 `--help` 为准。本机证据：Grok 有 `-p/--single`、`--prompt-file`；Claude 有 `-p/--print`；Codex 有 `exec`；Gemini 未装，二进制出现后再按其 `--help` 接。
- Job 适配只拼 help 里出现过的 flag。stdout / `--output-last-message` 一类官方收口写到 `output/`；没有收口就不宣称完成。
- `hasRecipe`：芯片引擎与 `recipePresence` 引擎相同，且后者不是 `.none`。禁止「头上 Grok、动作却当 Codex 已就绪」。

## 输入输出与依赖

输入：芯片所选引擎、该二进制 `--help`、Job 的 `workdir` / `promptFile` / `outputFile`。  
输出：`recipePresence`、Job 是否可 start、确认条文案、`output/` 文件。  
依赖：现有 Job 目录约定、RecipeCatalog Prompt、Shelf 收回。

## 文件 / 模块边界

- `01-requirements.md`、`02-prototype-design.md`、`03-tech-architecture.md`
- `design/modules/agent.md`、`job.md`、`ai-pane.md`
- `macos/Packages/DropAgentAgent/`
- `macos/Packages/DropAgentJob/Sources/JobService.swift`
- `macos/App/AppSession.swift`、`HotKeyCenter.swift`、`PanelRootView.swift`、`PanelPreview.swift`、`AppE2E.swift`
- `prototype/index.html`
- 与旧「只保证 Codex」冲突的 specs 改口，不另开产品方向

## 验收标准

1. Check：芯片 Grok 且 help 有单轮入口时 `recipePresence` 是 Grok；help 没有则是 `.none`。`Job.start` 在 Grok presence 上能跑（桩），不再因非 Codex 拒绝。
2. Check：隔离 copy 只在 `.workspace` 写 Workspace；Grok `.unknown` 是未确认，不是「在终端执行」。
3. Check：Grok / Claude 拼出的 Job 参数不含 always-approve / bypassPermissions / skip-permissions。
4. `--e2e`：仅终端（有 TUI、无执行入口）动作禁用，文案不再要 Codex；确认运行不把 Job 跑完。
5. 预览确认 / 运行中：执行者与芯片同一家，没有「不是 Grok 终端」。
6. 原型 `onlytui`：动作禁用，提示跟芯片走、无执行入口。
7. 四条进货链与原件 Hash 约定不变。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

- Grok `--sandbox` 的合法 PROFILE 未在 `--help` 列出，第一版不传该 flag，隔离按未确认。
- Gemini 未装：不编造 flag；装上且 help 有 `--prompt` / 等价 print 再启用。
