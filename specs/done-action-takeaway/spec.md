# 已完成条目在动作区指向拿走，不假装还能跑 Recipe

## 背景目标

`01`：结果回到托盘，由用户预览、复制、拖出。Job 成功后条目变成 `done`（例如 `summary.md`）。`recipeBatch` 不含 done，六个 Recipe 全灰。动作区却沿用「选中的材料不能跑这些动作」，像材料不合格。人刚跑完总结，点「动作」会以为失败了。

## 当前行为与问题证据

`workBody` 在非 confirm / running / 全 sent 时一律画 Recipe 网格。done 不进 `recipeBatch`，`recipeChooserHint` 落到「不能跑这些动作」。预览 `06-result` 停在结果 Tab，动作 Tab 没拍。

## 范围

- 选中项全部是 `done`：动作区不画六个按钮。写明可拖出；点「结果」拿走；有 TUI 则仍可发给终端。主按钮「打开结果」。
- 无 TUI：写明没有终端也能拖出或复制。
- 预览 `06b-done-work`：总结完成后动作 Tab 能读到「可拖出」和「打开结果」，没有「不能跑这些动作」。
- `--e2e` 验这一态。
- 有 idle / failed 混选时仍走 Recipe 网格。不改 Job、不改四条调用链。

## 非目标

- Developer ID。
- 不把 done 再塞进 `recipeBatch` 去跑第二次总结。
- 不改结果 Tab。

## 使用场景

总结跑完人点回「动作」：看见「可拖出」和「打开结果」，而不是一排灰按钮。

## 方案与关键决策

`AppSession.isDoneTakeaway` 判定。View 单独一条分支，对齐「已进终端」那条。

## 输入输出与依赖

输入：选中项 status、hasAgent。输出：动作区文案和「打开结果」。

## 文件 / 模块边界

- `macos/App/AppSession.swift`
- `macos/App/PanelRootView.swift`
- `macos/App/PanelPreview.swift`
- `macos/App/AppE2E.swift`
- 本 spec

## 验收标准

1. 预览 `06b-done-work` 能读到「可拖出」和「打开结果」，不含「不能跑这些动作」。
2. `--e2e`：条目 `done` 且选中 → `isDoneTakeaway`，hint 含「点「结果」拿走」。
3. 预览 `03-idle` 仍有 Recipe 网格和「或在下面写一句话」。
4. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

无。
