# Grok 终端会话自动批准工具调用

## 背景与目标

发给 Grok 的终端会话会在 `run_terminal_command` 上停住等批准。DropAgent 不解析 TUI、面板也不给 TUI 会话出「允许」按钮。人在输入框写「批准」会被当成新消息，把等待中的命令冲掉。目标：Grok 终端会话不再弹出工具批准，任务能自己跑完。

## 当前行为与问题证据

- TUI 启动：`grok --no-alt-screen --cwd <副本> <injection>`，没有 `--always-approve`。
- 隔离 `GROK_HOME` 不拷用户的 `permission_mode`；已有隔离配置里 Grok 自己写了 `[ui] yolo = false`。
- 读文件自动过；终端命令进入 `permission_prompt`。面板「等待授权」只给 Recipe（`.running`），TUI 条目是 `.sent`。
- Recipe / `HeadlessCLI` 仍不传 `--always-approve`。本任务不改那条链。

## 范围与非目标

- 只改 **Grok TUI** 启动参数：加上 `--always-approve`。
- 隔离 home 仍不拷用户 MCP / Hooks / 用户自己的 always-approve。种子 `config.toml` 仍只抄隐私确认。
- 不覆盖已存在的隔离配置。CLI 覆盖该次进程（含已有 `yolo = false` 的 home）。
- 不加 `--permission-mode bypassPermissions` 别名。
- 不给 Recipe 加 always-approve。
- 其他预置 TUI 的自动批准见后续 `specs/tui-always-approve/spec.md`。
- 不解析 TUI、不代点卡片。

## 方案

`InteractiveLaunch.arguments(.grok)` 在 `--no-alt-screen` 与 `--cwd` 之间加入 `--always-approve`，且必须在 positional injection 之前。

## 文件边界

- `macos/Packages/DropAgentAgent/Sources/InteractiveLaunch.swift`
- `macos/Check/main.swift`（TUI Grok 断言；Recipe Grok 仍禁止该 flag）
- `design/modules/tui.md`、`specs/multi-tui/spec.md`、`specs/grok-isolated-home/spec.md` 同步一句

## 验收标准

1. Check：Grok TUI `PreparedTUISend.session.arguments` 含 `--always-approve`，不含 `bypassPermissions`。
2. Check：Grok Recipe `HeadlessCLI.arguments` 仍不含 `--always-approve`。
3. Check：隔离种子仍无 MCP、仍不从用户配置拷 always-approve / yolo。
4. 其他预置 TUI 见 `specs/tui-always-approve/spec.md`。
5. `cd macos && swift run DropAgentCheck` 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
```
