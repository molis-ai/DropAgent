# Recipe 失败保留人话原因

## 背景目标

`01` 要求执行中能看到失败原因。Job 一 catch 就把 `event` 写成「任务失败」，Codex JSONL 刚报的「失败」被盖掉。

## 当前行为与问题证据

`JobService.start` 的 `catch`：`failureReason = "任务失败"`，`event = "任务失败"`。

## 范围

- 最后一条事件若已是失败类文案（含「失败」），用作 `failureReason` / `event`。
- 没有这类事件时仍写「任务失败」。
- 取消仍回 idle，不标失败。

## 非目标

- 不把退出码、stderr 原文铺到面板。
- 不跑真机 Codex。

## 验收

1. Check：Agent 先报「失败」再抛错 → 条目 `failureReason == "失败"`。
2. Check：直接抛错、没有失败事件 → 「任务失败」。
3. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
```
