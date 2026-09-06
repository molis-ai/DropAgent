# Job.job(id) 读真实 manifest

## 背景目标

`design/modules/job.md` 的 `job(id:)` 应返回这次任务的 Recipe、条目、产出。实现永远写成「总结文件」、空条目、output 目录。

## 当前行为与问题证据

`JobService.job(id:)` 写死 `recipe: .summarize`、`itemIDs: []`，`outputFile` 指向目录。

## 范围

- `manifest.json` 的每条材料带上 Item id。
- `job(id:)` 读 manifest：recipe、itemIDs、产出文件（有 `output/<name>` 就用文件，否则用 output 目录）。
- 没有 manifest 返回 nil。
- `cancel()` 仍是第一版同时只跑一个，不改成按 id 取消。

## 非目标

- 不改四条调用链、不跑真机 Codex。

## 验收

1. Check：总结跑完后 `job(id).recipe == .summarize`，含该条目 id，`outputFile` 文件名是 `summary.md`。
2. Check：抽取跑完后 recipe 是 extract，文件名 `extracted.json`。
3. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
```
