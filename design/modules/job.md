# 模块：Job

包：`DropAgentJob`。编排在 `JobService`，副本目录磁盘操作在 `JobWorkspace`。

## 做什么

对选中条目做**副本任务**：建 `Jobs/<id>`、按 Recipe 调 Agent、把完整结果收到 `output/`、记 `events.jsonl`、跑完校验原件 Hash、把输入 `patch` 回 idle、`Shelf.addResult` 追加产出。人还停在这次材料上时，App 选中该结果并打开内容台。

## 不做什么

不画 UI。不投递 TUI。不改用户原路径上的文件。不加载用户全局 MCP（通过 Agent 的隔离配置）。

## Public

```text
start(itemIDs: [ItemID], recipe: RecipeID, optionID: String? = nil) async throws -> JobID
cancel()                 // 第一版同时只跑一个
job(id:) -> JobRecord?   // 读 manifest.json；没有则 nil
deleteOwnedOutput(_ record: ResultRecord)  // 删 Jobs 下该任务目录；路径必须在 Jobs 根之内，不删整个 Jobs
```

开始前：条目必须是 idle（或 failed 可重试）。`confirm` 由 App 处理，点确认才 `start`。

## 目录

```text
Application Support/DropAgent/Jobs/<id>/
  input/    从 Item.parts / Inbox 复制，只读
  work/     Agent cwd
  output/   唯一允许回到架子的新文件
  manifest.json
  events.jsonl
```

复制，不用 symlink。Prompt 只含 `work/` 相对路径，并要求把完整结果写成约定文件名；文件里必须是交付正文，不要只口头回复，也不要写「已写入某某文件」。

Agent 退出后 `RecipeOutput.collect` 按这个顺序收取：`output/` 里已有可用正文 → `work/` 里同名新文件 → `work/` 里非材料的新文本 → 看起来像交付的 stdout。进度句（如「工具调用完成」「在写结果」）和短的完成口播（如「已整合三份材料。」或「已把材料整合成 brief.md」）不当交付。收不到文件则 `JobError.missingOutput`，结果区失败卡不挂空文件。本机 `imageText` / `pdfText` 仍写 `ocr.md` / `pdf.md`，走同一收取。侧栏结果标题对重名编号，磁盘文件名仍是约定产出名。

## Recipe（第一版六个 CLI 名字 + 本机文字提取）

每个 Recipe 声明：要哪些 kind、最少几份（「整合」为 2，其余 1）、产出文件名、是否需要网络、是否需要 Agent。CLI Recipe 默认按 Agent 配置。`imageText` 只接受图片，`requiresAgent = false`，用本机 Vision 写 `ocr.md`。`pdfText` 只接受 PDF，同样不需要 Agent，用 PDFKit 抽内嵌文字写 `pdf.md`。

禁止开放「任意 shell 一行」。新 Recipe = 新声明，不是用户贴脚本。

## Hash

`admit` 时 Ingest 把原件 checksum 写入 Item（或 Job start 时对 `sourceURL` 现算并写入 manifest）。跑完再读原路径，不一致 → Job failed，output 仍可给用户看，UI 必须说「原件中途变了，结果按副本做的」。

## 调用

CLI Recipe：`Agent.run(config)`（执行者是 `recipePresence` 那家 CLI，不是写死 Codex）。`imageText` / `pdfText` 不调 Agent：前者识别任务副本里的图，后者抽 PDF 内嵌文字。`Shelf.patch` 把输入拉回 idle；`Shelf.addResult` 追加产出。取消不写结果。需要 Agent 的 Recipe 在没有 `recipePresence` 时 `start` 失败，条目保持 idle。
