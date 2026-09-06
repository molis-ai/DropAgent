# App 端到端：抽取和新交付也能拖出

## 背景目标

`03` §9.7：其余 Recipe。内核 Check 已用 FakeAgent 跑抽取 / 翻译 / 脱敏 / 转 MD / 新交付。App `--e2e` 只走总结。壳上 `chooseRecipe` → `confirmRun` → 拖出，对抽取和「至少两份」的新交付没有证据。人不准用真 Codex。

## 当前行为与问题证据

`RecipeStubAgent` 不论产出文件名都写同一句 Markdown。抽取要 `extracted.json`，新交付要两份材料才 `Job.start`。e2e 从未 Command 多选后点「新交付」。

## 范围

- 桩按产出扩展名写货：`.json` 写 JSON 对象，其余写 Markdown。
- `--e2e`：一份 PDF → 抽取 → 原件 Hash 不变 → 拖出 `extracted.json`，正文是 JSON。
- `--e2e`：两份 Markdown → 新交付 → 拖出 `brief.md`。
- 测完删掉这些条目，后面总结 / 抓页 / Grok 仍过。
- 不改四条调用链，不跑真 Codex。

## 非目标

- Developer ID。
- 不把翻译/脱敏/转 MD 再各跑一遍（Check 已覆盖，产出同属 Markdown）。
- 不把桩接到正式启动。

## 使用场景

放下 PDF 抽字段，拖走 JSON。Command 点两份材料做一份 briefing，拖走。

## 方案与关键决策

仍用现有 Job 桩。多选走 `toggleSelect(..., command: true)`，与面板 Command 点同一条 API。

## 输入输出与依赖

输入：测试 PDF、两份 md。输出：桌面 `extracted.json` / `brief.md`、原件 Hash。

## 文件 / 模块边界

- `macos/App/AppE2E.swift`
- 本 spec

## 验收标准

1. `--e2e`：抽取后原 PDF Hash 不变；落地 `extracted.json`；正文是 JSON 对象。
2. `--e2e`：两份材料新交付后落地 `brief.md`；两条都 `done`。
3. `--e2e`：随后总结、抓页、Grok 发送仍过。
4. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

翻译需要联网声明，仍由 Check 覆盖 `needsNetwork`，本刀不跑。
