# 模块：Job

包：`DropAgentJob`

## 做什么

对选中条目做**副本任务**：建 `Jobs/<id>`、按 Recipe 调 Agent、写 `output/`、记 `events.jsonl`、跑完校验原件 Hash、把输入 `patch` 回 idle、`Shelf.addResult` 追加产出。

## 不做什么

不画 UI。不投递 TUI。不改用户原路径上的文件。不加载用户全局 MCP（通过 Agent 的隔离配置）。

## Public

```text
start(itemIDs: [ItemID], recipe: RecipeID) async throws -> JobID
cancel()                 // 第一版同时只跑一个
job(id:) -> JobRecord?   // 读 manifest.json；没有则 nil
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

复制，不用 symlink。Prompt 只含 `work/` 相对路径。

## Recipe（第一版六个名字，正文另文件）

每个 Recipe 声明：要哪些 kind、最少几份（「新交付」为 2，其余 1）、产出文件名、是否需要网络（翻译可能需要；默认按 Agent 配置）。第一版先做「总结文件」跑通。

禁止开放「任意 shell 一行」。新 Recipe = 新声明，不是用户贴脚本。

## Hash

`admit` 时 Ingest 把原件 checksum 写入 Item（或 Job start 时对 `sourceURL` 现算并写入 manifest）。跑完再读原路径，不一致 → Job failed，output 仍可给用户看，UI 必须说「原件中途变了，结果按副本做的」。

## 调用

`Agent.run(config)`（执行者是 `recipePresence` 那家 CLI，不是写死 Codex）；`Shelf.patch` 把输入拉回 idle；`Shelf.addResult` 追加产出。取消不写结果。没有 `recipePresence` 时 `start` 失败，条目保持 idle。
