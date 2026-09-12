# 整合结果必须是合成稿，不是完成说明

状态：已实现。完成等级 3。唯一需求书。依据本会话「三份材料整合后 brief.md 只有『已把三份材料整合成 brief.md。』」。

## 背景目标

人多选材料点「整合」，要拿到一份可读的合成稿。现在结果区打开的是一句完成汇报。

## 当前行为与问题证据

- 整合指令只有「把这些材料整合成一份完整 Markdown」，再加「写成文件：brief.md」。Grok 把它理解成去生成该文件，口头回复一句交差。
- `PrintCLI` 在 `output/brief.md` 为空时把 stdout 写成该文件。`RecipeOutput.collect` 先信 `output/`，不再去收 `work/brief.md`。完成口播被当成可用正文。

## 范围与非目标

范围：收紧共用护栏和整合指令；完成口播不当交付，继续收 `work/` 里的正文；没有正文则任务失败。

非目标：不改六个动作的选项、产出文件名、Grok 调用参数；不把 Agent 包依赖 Job。

## 使用场景

选三份文稿点整合、篇幅「完整一份」。结果区打开 `brief.md` 是合成稿（事实、结论、数字来自材料），不是「已把三份材料整合成 brief.md。」

## 方案与关键决策

1. 护栏写明：约定文件里必须是交付正文，不要写「已写入某某文件」。
2. 整合指令改成「写成合成稿」，并禁止完成说明。
3. `looksLikeDeliverable` 拒绝短的完成口播。`collect` 仍按原顺序，只是 `output/` 里的口播不再挡住 `work/` 收取。

## 文件 / 模块边界

- `macos/Packages/DropAgentJob/Sources/RecipeOptions.swift`
- `macos/Packages/DropAgentJob/Sources/RecipeOutput.swift`
- `macos/Check/main.swift`
- `design/modules/job.md`、`01-requirements.md`

## 验收标准

1. `RecipeCatalog.prompt(for: .brief)` 要求写成合成稿，并禁止「已生成 brief.md」这类完成说明。
2. `looksLikeDeliverable("已把三份材料整合成 brief.md。") == false`；`looksLikeDeliverable("已整合三份材料。") == false`；真正短总结「这是总结」仍为 true。
3. `output/brief.md` 是完成口播、`work/brief.md` 是合成稿时，`collect` 留下合成稿。
4. 只有完成口播、没有其它正文 → `missingOutput`。
5. `cd macos && swift run DropAgentCheck` 通过。

## 假设

Grok 仍可能只口头回复；那时应失败而不是交付一句汇报。
