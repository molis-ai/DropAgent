# 所有预置 TUI 终端会话自动批准工具调用

## 背景与目标

DropAgent 不解析 TUI、面板也不给终端会话出「允许」。Grok 已用 `--always-approve` 绕开。Claude / Codex 等同款会问的 TUI 仍会停住，输入框再发字会把批准冲掉。目标：所有预置 TUI 发送不再等工具批准；Recipe 副本链不变。

## 当前行为与问题证据

- 面板「等待授权」只给 `.running` Recipe。TUI 条目是 `.sent`。
- `InteractiveLaunch` 里只有 Grok 带 `--always-approve`。其余 TUI 仍走默认「要问」。
- 跟进消息整段打进 PTY，会取消正在等的批准。

## 范围与非目标

只改预置 TUI 启动参数（positional injection 之前）：

| 引擎 | 加上 |
|---|---|
| Grok | `--always-approve`（已有） |
| Codex | `--ask-for-approval never`（保留 sandbox，不加 dangerously-bypass） |
| Claude | `--permission-mode bypassPermissions` |
| Gemini / Qwen | `--yolo` |
| OpenCode | `--auto` |
| Cursor CLI / Kimi | `--yolo` |
| CodeBuddy | `--dangerously-skip-permissions` |

- Recipe / `HeadlessCLI` / `CodexCLI.execArguments` 不加这些 flag。
- 自定义 TUI / 纯 CLI 不发明未知 flag。
- 不解析画面、不代点、不拷用户 MCP。
- Codex 不加 `--dangerously-bypass-approvals-and-sandbox`。

## 方案

改 `InteractiveLaunch.arguments`。CLI flag 覆盖该次进程；隔离配置仍不拷用户 yolo。

## 文件边界

- `macos/Packages/DropAgentAgent/Sources/InteractiveLaunch.swift`
- `macos/Check/main.swift`（TUI 断言改为含上述 flag；Job 仍禁止）
- `design/modules/tui.md`、`specs/multi-tui/spec.md`、`specs/extra-runtimes/spec.md`、`specs/runtime-coding-clis/spec.md`、`specs/grok-tui-always-approve/spec.md`

## 验收标准

1. Check：上表每家 TUI `PreparedTUISend.session.arguments` 含对应 flag。
2. Check：Codex TUI 不含 `--dangerously-bypass-approvals-and-sandbox`。
3. Check：Grok / Claude / Cursor / Kimi / CodeBuddy / Qwen / OpenCode 的 Job argv 仍不含对应 skip/yolo/auto/always-approve。
4. Check：Kimi TUI 仍不含 `-p` / `--prompt`。Cursor TUI 仍不含 `--force`。
5. `cd macos && swift run DropAgentCheck` 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
```
