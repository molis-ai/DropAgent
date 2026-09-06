# 「新交付」至少两份材料

## 背景目标

`01` 里「根据多份材料生成一个新交付」的输入是多文件组合。现在选一份也能点「新交付」，Job 也会跑。

## 当前行为与问题证据

Check 里 `RecipeID.allCases` 循环用**一份** PDF 跑 `brief`，并且通过。面板 `recipeFitsSelection` 只看 kind，不看份数。预览没有多选画面。

## 范围

- `brief` 至少 2 份可运行材料（idle / confirm / failed，且 kind 合格）。
- Job.start 不足则 `notStartable`，架子条目保持原状态。
- 面板：一份时「新交付」禁用；说明是至少两份，不是 kind 不对。
- 架子有超过一条时，动作区写明 Command 点多选。
- 预览补多选和「对 2 项 · 新交付」确认。
- 不改另外五个 Recipe 的一份即可跑。

## 非目标

- Developer ID。
- 不把 Recipe 接到 Grok。
- 不做 Shift 连续选。

## 使用场景

1. 架子上只有一份 PDF：六个动作里「新交付」是暗的。
2. Command 点选两份文稿，点「新交付」：权限条写「对 2 项」，确认后一份 `brief.md`。
3. 两份里有一份 kind 不合格：不合格的不进入确认，够两份合格才进入。

## 方案与关键决策

规则放在 `RecipeID.minimumCount`（brief=2，其余=1），Job 与面板共用，不在 View 里写死数字。

## 文件 / 模块边界

- `DropAgentJob`：`RecipeID` + `JobService.start`
- `macos/App`：`recipeFitsSelection`、按钮 help、预览
- Check：一份 brief 失败；两份 brief 仍成功；全量循环不再用一份跑 brief

## 验收

1. Check：一份材料 `start(..., .brief)` 抛 `notStartable`，条目仍 idle。
2. Check：两份 markdown 的 brief 仍产出 `brief.md`，原件 Hash 不变。
3. 预览 `13-multi`：两份都选中，「新交付」可点；`13b-brief`：确认区是「对 2 项」。
4. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
```
