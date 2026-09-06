# App 端到端：无 TUI / 无 Codex 门禁

## 背景目标

`03` §10.3：无 TUI 时发送禁用、进货仍可；无 Codex 时 Recipe 禁用，有 TUI 仍可发送。内核 Check 已验 `Job.start` 在非 Codex 上拒绝。`--e2e` 强制 Grok，从未把「没有终端」和「只有终端」两条门禁走完：AI 区放下仍进架子、发送不跑、确认运行被 `hasRecipe` 拦住。

## 当前行为与问题证据

`AppSession.admitToTUI` 无 Agent 时仍 `admit` 并写「文件已留在架子上」。`confirmRun` 无 Codex 直接返回。这两条在 App 进程里没有 e2e 断言。预览有 `02-no-agent` / `03c-tui-only`，不能代替壳上的调用。

## 范围

- `--e2e`：把 `presence` / `recipePresence` 打成无终端、仅终端，走 `admitToTUI` 与 `confirmRun`。
- 无终端：条目进架子且仍是 idle，发送不改状态。
- 仅终端（假 Grok 路径，不真正 launch）：`canSendToTUI` 为真，`hasRecipe` 为假，`confirmRun` 不把 Job 跑完（即使 e2e Job 桩能跑）。
- 无 TUI、有 Codex：`hasRecipe` 为真，发送仍禁用；不在这一格调用 `confirmRun`（总结闭环已由 `recipe-app-e2e` 覆盖）。
- 测完 `refreshPresence()`，后面仍走真 Grok 发送。
- 不改四条调用链，不装/卸本机 CLI。

## 非目标

- 真把 Safari 放到最前做 §10.4。
- Developer ID。
- 不调本机 Codex。

## 使用场景

没装任何 TUI：仍能把文件丢进架子。只装了 Grok：能发送，不能点总结。

## 方案与关键决策

不卸载 Grok。e2e 里改 session 上的探测结果，证明壳读的是 `hasAgent` / `hasRecipe`，不是 Job 桩。仅终端不调用 `sendToTUI`，避免把 `/usr/bin/true` 当 TUI 拉起。

## 输入输出与依赖

输入：测试 PDF。输出：架子条目状态、`errorText`、`canSendToTUI` / `hasRecipe`。依赖现有 `admitToTUI`、`confirmRun`。

## 文件 / 模块边界

- `macos/App/AppE2E.swift`
- 本 spec

## 验收标准

1. `--e2e`：无 TUI 时 `admitToTUI` 后条目 idle，架子上有文件，发送未把状态改成 sent。
2. `--e2e`：仅终端时 `hasRecipe == false`、`canSendToTUI == true`，`confirmRun` 后条目仍是 confirm，没有 `summary.md`。
3. `--e2e`：无 TUI 有 Codex 时 `hasRecipe == true`、`canSendToTUI == false`。
4. `--e2e`：随后 Grok 发送仍过。
5. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

本机若已装 Codex，`refreshPresence` 之后 `hasRecipe` 会变回真；门禁只在覆盖探测结果的那一段成立。
