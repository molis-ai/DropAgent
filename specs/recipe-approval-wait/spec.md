# 等待授权时说明面板点不了同意

## 背景目标

`01` 要求执行中能看懂谁在跑、失败怎么恢复。Recipe 走 `codex exec`，没有交互画面。Codex JSONL 报 `exec_approval` 时面板写成「等待授权」。人会以为要去「终端」点同意，但那个 Tab 是 Grok / 当前 TUI，不是这次 Codex 副本。

## 当前行为与问题证据

预览 `05b-waiting`：动作区是「等待授权」+「Grok 在任务副本里跑。」+「取消」。没有写这里点不了同意。`recipe-running-actor` 写明执行者跟芯片，但等授权时仍缺恢复说明。禁止给 Job 加 `--always-approve` / `bypassPermissions`。

## 范围

- 选中项 `running` 且事件含「等待授权」：动作区在执行者句下方加一句，写明这里点不了同意，等当前芯片那家 CLI 自己过，或取消。
- 不提「去终端点同意」。
- 预览 `05b-waiting` 能读到这句。
- 不改 `execArguments`、不改四条调用链、不加任何跳过授权的 flag。

## 非目标

- Developer ID。
- 不做授权 UI、不解析 TUI 画面去点同意。

## 使用场景

点「在副本中运行」后卡片停在「等待授权」。人看见「这里点不了同意」，选择等或取消，而不会切到 Grok 终端空等。

## 方案与关键决策

只补人话。授权策略仍是该 CLI 无界面入口自己的行为；面板不假装能代点。

## 输入输出与依赖

输入：条目 `status == .running` 且 `event` 含「等待授权」。输出：动作区多一行文案。依赖现有 JSONL →「等待授权」映射。

## 文件 / 模块边界

- `macos/App/HotKeyCenter.swift`
- `macos/App/PanelRootView.swift`
- 本 spec

## 验收标准

1. 预览 `05b-waiting` 能读到「点不了同意」，且不含「去终端」。
2. 预览 `05-running`（工具调用）没有这句。
3. Check 全绿；`CodexCLI.execArguments` 不含 always-approve / bypass / dangerously-skip。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
```

## 假设与开放问题

无。
