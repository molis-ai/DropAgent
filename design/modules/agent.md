# 模块：Agent

包：`DropAgentAgent`

## 做什么

发现本机 CLI、给出隔离档文案、产出「怎么跑」的执行配置。Recipe 和发送都跟芯片。预置 TUI：Grok / Claude / Gemini / OpenCode / Cursor CLI / Codex / Kimi Code / CodeBuddy / Qwen Code。设置里可输入命令名或添加自定义 Runtime。没有可收口 Job 入口的引擎，`recipePresence` 为 `.none`。

## 不做什么

不持有架子。不写 Jobs 目录（cwd 由 Job 传入）。不解析 TUI 帧。不接云端 API Key、不接 Ollama。

## Public

```text
discover() / recipePresence() -> AgentPresence
  // 芯片 Runtime 且 --help 能证明无界面入口（纯 CLI 本身可收口）
  // 否则 .none

tuiPresence() -> AgentPresence
  // 所选 Runtime，或 .none

installedEngines() -> [AgentPresence]
  // 预置已装 ∪ 自定义且可执行

isolationCopy(for presence) -> String   // 跟 isolation 档走，不许营销升级

run(workdir: URL, promptFile: URL, isolation: Isolation) async throws -> AgentRunResult

ensureInteractiveSession() throws -> SessionHandle  // 给 TUI 模块
```

没有二进制：对应 Presence == `.none`。Job.start 必须 `recipePresence.executable != nil`；TUI.send 必须 `tuiPresence.executable != nil`。禁止自行 PATH 乱猜两套逻辑。

## Recipe 跑法

- 探测：`PATH` 与 `~/.grok/bin`、`~/.local/bin`、`~/.opencode/bin`、`~/.cursor/bin`、`~/.kimi-code/bin`、WorkBuddy.app 内置 CLI 等，再设置里用户指定 / 自定义命令。文件名 `agent` 用 `--help` 区分 Grok Build 与 Cursor CLI；不要把 `~/.grok/bin/agent` 认成 Cursor。
- Recipe 跟 `tuiPresence` 同一 Runtime。优先官方非交互入口（`codex exec`、`grok --prompt-file` / `--single`、`claude -p/--print`、`opencode run`、Cursor / CodeBuddy `-p/--print`、Gemini / Kimi / Qwen `--prompt`），以本机 `--help` 为准。cwd = `work/`。不传 `--auto` / `--yolo` / `--dangerously-skip-permissions`。
- 没有可收口入口：`recipePresence == .none`，不许解析 TUI、不许模拟按键、不许假装完成。
- 隔离：能证明官方工作区限制在生效，才允许 UI 写「Workspace Sandbox」；否则写「未确认工作区限制，仍在副本目录跑」。TUI / CLI 发送档才写「在终端执行，不是副本沙箱」。
- 不把用户全局 MCP/Hooks 带进 Recipe 跑法（能关就关；关不掉要在文案里说实话）。

## 扩展

新预置 = `AgentEngine` 加一家。自定义 = `AgentSettings.customRuntimes`。Job 签名不变。芯片同时决定终端和快捷动作。
