# 动作一律产出文件，结果区自动打开

## 背景目标

默认动作和自定义动作跑完，结果区要出现一份能看见正文的新文件，并自动打开这份产出。现在常只剩一张空卡片。

## 当前行为与问题证据

- Prompt 写「作为最终回复 / 最终回复为 Markdown」。打印型 CLI 把 stdout 写进 `output/`；Claude / Kimi / CodeBuddy / Qwen 这类编码 Agent 往往在 `work/` 里另存文件，stdout 是进度或空。
- `JobService` 成功路径只要 Agent 不抛错就 `addResult`，即使 `output/summary.md` 不存在或只有「工具调用完成」这类进度句。
- Codex 无界面入口把 JSONL 最后一条事件写进 `output/`，经常是「工具调用」「在写结果」，不是交付正文。
- 结果区预览只 `String(contentsOf: output)`。文件空或没有，内容台什么都不画。人以为没产出。
- 跑完若人还停在这次材料上，会 `adoptNewestResult`；文件本身坏了，自动选中也看不见正文。

## 范围

- 所有 CLI 动作（六个默认 + 自定义）Prompt 改为：不要改材料文件，把完整结果写成指定文件名（如 `summary.md`、`source-抽付款日.md`）。不要只在对话里口头回复。
- 跑完收取顺序：`output/` 里已有可用正文 → `work/` 里同名新文件 → `work/` 里非材料的新文本 → 看起来像交付的 stdout。进度句不当交付。
- 收到后拷进 `output/<约定文件名>`，JSON 仍拆围栏。结果区卡片指向这份文件。
- 收不到可用文件：任务失败，原因「这次没有生成文件」，`output == nil`，不挂空文件。
- 本机文字提取仍直接写 `ocr.md` / `pdf.md`，走同一收取。
- 人还停在这次材料上时，自动选中刚产出的结果，内容台打开该文件。不打断别人正在看的材料、草稿或对话。

## 非目标

- 不把「对话 / 发给终端」改成再造一份结果文件（仍不解析 TUI）。
- 不覆盖用户原件。Prompt 仍不含原件路径。
- 不发明 `--yolo`。不改四条进货链。不 commit / push。

## 使用场景

1. 选 PDF，点总结。Kimi 在 `work/` 写下 `summary.md`，stdout 只有「工具调用完成」。结果区出现 `summary.md`，内容台打开那份总结，左列仍是原 PDF。
2. 自定义「抽付款日」，约定文件 `报价-抽付款日.md`。Agent 把正文写进该文件名。结果区打开它。
3. Agent 什么文件都没写、stdout 也只是进度：结果区是失败卡「这次没有生成文件」，可回材料重试。
4. 翻译 stdout 直接打出 Markdown、`work/` 没新文件：仍把这段写成 `translated.md` 并打开。

## 方案与关键决策

- `RecipeCatalog.fileGuardrail(outputFileName:)` 统一默认与自定义。
- `RecipeOutput.collect` 负责收取；进度句黑名单来自现有 Codex / PrintCLI 事件文案，不靠字数误伤短交付。
- `JobError.missingOutput` 给失败文案。App `human` 与 Job `failureCopy` 同一句。
- `adoptNewestResult` 按这次 `sourceItemIDs` 选最新结果，避免误打开更早的卡。

## 输入输出与依赖

输入：Recipe / 自定义 Prompt、Agent stdout、`work/` 新文件、`output/`。  
输出：`output/` 下约定文件名、结果区卡片、内容台正文。  
依赖：现有 Job 目录、结果区、`presentJobResult` 不抢焦点规则。

## 文件 / 模块边界

- `macos/Packages/DropAgentJob/`（`RecipeOutput`、`RecipeOptions`、`JobService`、`JobTypes`）
- `macos/App/AppSession+Job.swift`、`AppSession.swift`
- `macos/Check/main.swift`、`macos/App/AppE2E.swift`
- `01-requirements.md`、`02-prototype-design.md`、`design/modules/job.md`

## 验收标准

1. Check：Prompt 含 `写成文件：summary.md`；自定义含约定 `.md` 名；不含原件路径。
2. Check：Agent 只在 `work/summary.md` 写正文、lastMessage 为「工具调用完成」→ 结果区文件正文是那份总结。
3. Check：Agent 既无新文件、lastMessage 又是进度句 → `missingOutput`，结果 `failed` 且 `output == nil`。
4. Check：FakeAgent 仍写 `output/` 的旧路径（「这是总结」）继续成功。抽取围栏 JSON 仍拆成对象。
5. `--e2e` recipe：总结后自动选中 `summary.md`，`stagedItem` 是该结果。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
```

## 假设与开放问题

- 本机未装真 Agent：用桩测收取。真机 Kimi/Claude 是否总把文件写成约定名，靠 Prompt + `work/` 新文件兜底。
- 文件夹材料：不把材料目录里的原文件当交付。
