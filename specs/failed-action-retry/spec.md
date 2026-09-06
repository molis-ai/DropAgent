# 动作区写出失败原因，并说明可以重试

## 背景目标

`01` 要求执行中能看到失败原因。Job 把原因写在条目上，结果 Tab 有黄字。人点回「动作」只看到六个按钮，像没失败过。`job.md`：failed 可重试。

## 当前行为与问题证据

预览 `11-hash` 停在结果 Tab。随后 `12-hotkeys` 切到动作：失败条仍选中，动作区没有原因，也没有「可以再点动作」。`confirmRun` 失败会切到结果，但动作仍是主入口。

## 范围

- 选中项含 `failed` 且有 `failureReason`：动作区 Recipe 网格上方用警告色写出原因。
- 有 Codex：再加一句「再点一个动作可以重试。」
- 无 Codex：只写原因，不承诺能点动作。
- 预览 `11c-failed-retry`：Grok 仍在、动作 Tab、无产出的失败，能读到原因和重试句。Hash 失败且已有 output 的动作区见 `failed-output-takeaway`。
- `--e2e` 验这两句。
- 不改 Job 失败映射、不改四条调用链。`12-hotkeys` 页脚仍是快捷键被占用。

## 非目标

- Developer ID。
- 不跑真机 Codex。
- 不把失败自动改回 idle。

## 使用场景

总结失败后点「动作」：看见「任务失败」和「再点一个动作可以重试。」，再点总结进入确认。Hash 不一致时看见「原件中途变了…」，结果仍可在结果 Tab 拖出。

## 方案与关键决策

文案挂在 `AppSession`。View 只在 Recipe 网格这条分支展示，确认 / 运行中 / 已进终端不重复。

## 输入输出与依赖

输入：选中项 `status` / `failureReason` / `hasRecipe`。输出：动作区一到两行。

## 文件 / 模块边界

- `macos/App/AppSession.swift`
- `macos/App/PanelRootView.swift`
- `macos/App/PanelPreview.swift`
- `macos/App/AppE2E.swift`
- 本 spec

## 验收标准

1. 预览 `11c-failed-retry` 能读到「任务失败」和「再点一个动作可以重试」。
2. `--e2e`：failed + 有 Codex → 原因与重试句；去掉 Codex → 有原因、无重试句。
3. 预览 `12-hotkeys` 页脚仍含「快捷键被占用」。
4. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

无。
