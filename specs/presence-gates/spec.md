# App 端到端：无 TUI / 无执行入口门禁

## 背景目标

`03` §10.3：无 TUI 时发送禁用、进货仍可；芯片对应 CLI 不能跑 Job 时 Recipe 禁用，有 TUI 仍可发送。

本项被 `specs/recipe-follows-chip/spec.md` 改口：不再用「无 Codex」当 Recipe 门禁。

## 范围

- `--e2e`：无终端、仅终端（有 TUI、无执行入口）。
- 无终端：条目进架子且仍是 idle，发送不改状态。
- 仅终端：`canSendToTUI` 为真，`hasRecipe` 为假，`confirmRun` 不把 Job 跑完。
- 没有芯片时，即使 `recipePresence` 残留某家 CLI，`hasRecipe` 仍为假。
- 测完 `refreshPresence()`。
- 不改四条调用链。

## 非目标

- 真把 Safari 放到最前。
- Developer ID。
- 不调本机真实 Recipe CLI 跑总结。

## 验收

1. 无 TUI：发送禁用，动作禁用，进货仍可。
2. 仅终端：发送可用，动作禁用，文案说没有无界面执行入口，不提「需要 Codex」。
3. Check / `--e2e` 全绿。
