# 删死代码、PrintCLI 环境解绑、隔离文案一处说话

## 背景与目标

复查发现三处该收：无人调用的 API、非 Codex Job 套了 Codex 环境、隔离人话两套事实源。用户行为不变，除结果页对 TUI 档会显示「在终端执行，不是副本沙箱」（以前 `IsolationShown.tui.spokenFact` 是空的）。

## 范围

1. 删 `IsolatedTUIHome.copyLogin(engine:)`、`CodexCLI.interactiveEnvironment`。`prepare()` 里的 Codex/Grok `copyLogin` 保留。
2. `PrintCLI` 用 `InteractiveLaunch.processEnvironmentMap`，不再用 `CodexCLI.recipeEnvironment`。Codex `exec` 仍用 recipe 环境。
3. `IsolationGrade.spokenFact` 是 Agent 对外句子。`AgentService.isolationCopy` 只转述它。`IsolationShown` 重叠档（workspace / unconfirmed / tui）人话必须逐字相同；`none` 仍为空（条目无档），`safeCopy` 仍是本机提取那档。不建 Utils，不合并 Hash。

## 非目标

- 不给 Recipe 加 always-approve。
- 不合并 FileDigest / stripSymlinks。
- 不拆 Check / AppE2E。

## 文件边界

- `DropAgentAgent`：`IsolationGrade`、`AgentService`、`InteractiveLaunch`、`PrintCLI`、`CodexCLI`
- `DropAgentTUI`：`IsolatedTUIHome`
- `DropAgentShelf`：`IsolationShown.spokenFact` 的 tui 句
- `macos/Check/main.swift`

## 验收标准

1. 工程内无 `copyLogin(engine:`、`interactiveEnvironment`。
2. Check：`isolationCopy(.tui)` 与 `IsolationShown.tui.spokenFact` 相同；workspace / unconfirmed 仍对齐。
3. Check：Codex `recipeEnvironment` 仍无 `CODEX_HOME`。PrintCLI / TUI 环境 PATH 含二进制目录。
4. `cd macos && swift run DropAgentCheck` 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
```
