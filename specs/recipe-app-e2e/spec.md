# App 端到端走通：总结后拖出 summary.md

## 背景目标

`03` §10.2：总结后原件 Hash 不变，`output/summary.md` 可拖到桌面。内核 Check 用 FakeAgent 已覆盖 Job + Pasteboard。`--e2e` 只走 Grok 发送原 PDF，不点 Recipe、不落地总结文件。人不准用真 Codex 做 live。面板这条主循环在壳上没有证据。

## 当前行为与问题证据

`AppSession` 把 `AgentService` 同时交给 Job 和 TUI。`--e2e` 进货后 `sendToTUI`，落地的是 `sample.pdf`。`confirmRun` → `job.start` 在 App 进程里从未被 e2e 跑过。没有 Codex 时 `hasRecipe` 为假，点总结会直接返回。

## 范围

- `AppSession` 可注入 Job 用的 `AgentRunning`；正式 App / `--preview` 仍用 `AgentService`。
- `--e2e` 注入只写 `output/summary.md` 的桩，不调 Codex 二进制。
- e2e：进一份 PDF → 点总结 → 确认运行 → 原件 Hash 不变 → 条目变成 `summary.md` / done → 拖到桌面的是总结，不是原 PDF。
- 之后仍走现有 Grok 发送。不改四条调用链、不改 `execArguments`。

## 非目标

- Developer ID。
- 不跑本机 Codex。
- 不把桩接到正式菜单栏启动。

## 使用场景

内部验收 `03` 第 10 节第 2 条：放下 PDF，跑总结，原件不动，新文件能拖到桌面。

## 方案与关键决策

TUI 仍用真 Grok。Job 在 `--e2e` 里换成桩，只证明壳把 Recipe 接到 Job.start 再接到拖出。桩的 `discover` 报 Codex workspace，好让 `hasRecipe` 为真。

## 输入输出与依赖

输入：测试 PDF。输出：`Desktop/summary.md`、原件 Hash。依赖现有 `chooseRecipe` / `confirmRun` / `PasteboardService.itemProvider`。

## 文件 / 模块边界

- `macos/App/AppSession.swift`
- `macos/App/AppE2E.swift`
- 本 spec

## 验收标准

1. `--e2e`：Recipe 后原件 Hash 不变。
2. `--e2e`：条目 `done`，title 为 `summary.md`，桌面落地文件名是 `summary.md`，正文是桩写的总结。
3. `--e2e`：随后 Grok 发送仍过。
4. 正式 `AppDelegate` / `--preview` 仍 `AppSession()`，Job 走 `AgentService`。
5. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

桩不证明 Codex `exec` 沙箱；那条仍由 Check FakeAgent + `execArguments` 覆盖。
