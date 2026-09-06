# 模块：Agent

包：`DropAgentAgent`

## 做什么

发现本机 CLI、给出隔离档文案、产出「怎么跑」的执行配置。Recipe 第一版只保证 Codex。TUI 支持 Grok / Claude / Gemini / Codex。

## 不做什么

不持有架子。不写 Jobs 目录（cwd 由 Job 传入）。不解析 TUI 帧。不接云端 API Key、不接 Ollama。

## Public

```text
discover() / recipePresence() -> AgentPresence
  // Codex：.codex(path, isolation: .workspace | .unknown) 或 .none

tuiPresence() -> AgentPresence
  // 所选 TUI：.grok / .claude / .gemini / .codex(..., .tui) 或 .none

installedEngines() -> [AgentPresence]

isolationCopy(for presence) -> String   // 给 UI 的原话，不许营销升级

run(workdir: URL, promptFile: URL, isolation: Isolation) async throws -> AgentRunResult

ensureInteractiveSession() throws -> SessionHandle  // 给 TUI 模块
```

没有二进制：对应 Presence == `.none`。Job.start 必须 `recipePresence` 为 Codex；TUI.send 必须 `tuiPresence != .none`。禁止自行 PATH 乱猜两套逻辑。

## Codex 第一版

- 探测：`PATH` 的 `codex`，再常见安装路径，再设置里用户指定。  
- Recipe：优先官方非交互入口（`codex exec` 一类，以本机 `--help` 为准，不要写死过时 flag）。cwd = `work/`。  
- 隔离：能证明官方工作区限制在生效，才允许 UI 写「Workspace Sandbox」；否则写「未确认工作区限制，仍在副本目录跑」。  
- 不把用户 `~/.codex` 里的 MCP/Hooks 带进 Recipe 跑法（能关就关；关不掉要在文案里说实话）。

## 扩展

Claude / Gemini / Grok TUI = 同一 `installedEngines` 联合结果。Job 签名不变，Recipe 仍只跑 Codex。设置里的 `tuiEngine` 只影响终端。
