# 多终端 Agent（Grok / Claude / Gemini / Codex）

## 背景目标

面板里的「发送 / 终端」现在写死 Codex。本机已经有 Grok Build（`grok`）和 Claude Code（`claude`）。人要在设置里选终端用哪个；Grok 和其他已装 TUI 都要能进内嵌 PTY。快捷动作跟同一颗芯片（见 `recipe-follows-chip`）。

## 当前行为与问题证据

- `AgentPresence` 只有 `.codex`；`TUIService` `guard case .codex`，参数写死 `--disable apps/hooks`、`CODEX_HOME`。
- 菜单栏 App 的 PATH 常常没有 `~/.grok/bin`，即使用户装了 Grok 也发现不了。
- 头上芯片只显示「Codex / 未发现 Codex」，不能换引擎。

本机（2026-09-05）：`~/.grok/bin/grok` 1.0.13，`~/.local/bin/claude` 2.1.206，`~/.local/bin/codex`；没有 `gemini`。

## 范围

- 探测：Codex、Grok、Claude Code、Gemini CLI。未装的在设置里显示「未安装」，不造假已连接。
- `AgentSettings.tuiEngine`：`auto | grok | claude | gemini | opencode | cursor | codex | llm | aichat | sgpt`，可另存每个引擎的可执行文件路径；自定义见 `specs/extra-runtimes/spec.md`。旧 `executableOverride` 仍当 Codex 路径。
- `auto` 顺序：Grok → Claude → Gemini → OpenCode → Cursor CLI → Codex（只在已装 TUI 里选；没有 TUI 才落到 llm / aichat / sgpt）。
- 明确选了未装的引擎：终端 = 没有，不偷偷换成别的。
- TUI 启动按引擎拼参数和环境；隔离 home，不把用户全局 MCP / Hooks / 原件路径送进会话。
- 头上芯片和右键菜单可选终端；换引擎后下一次发送开新会话。
- Recipe / `Job.start` 跟芯片：该 CLI `--help` 能证明无界面入口才启用；否则禁用并说清楚，有 TUI 仍可发送。

## 非目标

- 用没有可收口入口的 CLI 假装跑六个 Recipe。
- 解析 TUI 画面、模拟按键点菜单、`--dangerously-skip-permissions` / `--always-approve` / `bypassPermissions`。
- 加载用户 `~/.codex`、`~/.grok/config.toml` MCP、Claude 用户 MCP。
- Developer ID、Safari 真机抓页。

## 使用场景

1. 装了 Grok 且 help 有单轮入口：打开面板头上是 Grok，发送进 Grok TUI；总结也用 Grok 副本任务。
2. 设置里改成 Codex：发送和动作都进 Codex。
3. 只装 Claude 且有 `--print`：auto 用 Claude，动作也用 Claude。
4. 选 Gemini 但没装：发送禁用，芯片写未发现 Gemini，动作禁用。

## 方案与关键决策

- `discover()` / `recipePresence` = Codex，给 Job。`tuiPresence` / `installedEngines` 给终端。禁止 TUI 和 Job 各猜一套 PATH。
- Grok：`GROK_HOME` 指向任务隔离目录，拷 `auth.json`。首次写种子 `config.toml`（无 `mcp_servers` / 无 `always-approve`）；用户已有 `privacy_banner_acked` 则只抄这一行。已存在的隔离配置不覆盖。参数：`--no-alt-screen --cwd <副本> <injection>`。
- Claude：`CLAUDE_CONFIG_DIR` 隔离目录 + `--strict-mcp-config` + 空 `mcp.json`。不用 `--bare`（会丢掉 OAuth），不用 skip-permissions。`--setting-sources` 不含 user。
- Gemini：探测常见路径；有二进制则 `--prompt` 不用 yolo。无二进制则设置里未安装。
- 文案：终端区用引擎名；「未发现 Codex」只出现在 Recipe 语境。

## 输入输出与依赖

- 输入：`settings.json` 的 `tuiEngine` / 覆盖路径、PATH + `~/.grok/bin` 等常见目录。
- 输出：`PreparedTUISend.session` 的可执行文件、参数、环境；头上芯片和菜单状态。
- 依赖：本机已登录的对应 CLI。

## 文件 / 模块边界

- `DropAgentAgent`：引擎枚举、探测、Recipe/TUI 分流、交互启动参数。
- `DropAgentTUI`：仍只 `send`；按 `tuiPresence` 准备隔离 home，不写死 Codex。
- `DropAgentJob`：`discover()` 必须有可收口入口的芯片引擎。
- `macos/App`：设置菜单、芯片、文案。不在 View 里搜 PATH。
- 更新 `design/modules/{agent,tui,ai-pane,app-shell}.md` 与 `03-tech-architecture.md` §7。

## 验收标准

1. 同时存在 Grok 与 Codex、`tuiEngine=auto`，且 Grok `--help` 有单轮入口：`tuiPresence` 与 `recipePresence` 都是 Grok。
2. `tuiEngine=codex`：终端和动作都是 Codex，即使 Grok 在。
3. Grok 会话环境有 `GROK_HOME=` 隔离目录；隔离 `config.toml` 无 `mcp_servers`；不出现 `--always-approve` / `bypassPermissions`。
4. Claude 会话无 `--dangerously-skip-permissions`；有 `CLAUDE_CONFIG_DIR` 与 `--strict-mcp-config`。
5. 芯片 CLI 没有无界面入口：Recipe 禁用，发送可用。
6. 选未装 Gemini：发送禁用，不假装成功。
7. injection 仍不含原件绝对路径。
8. 头上芯片可打开引擎菜单；换引擎后 `tuiSessionDirectory` 清空。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-preview-root ./.build/debug/DropAgent --preview
```

## 假设与开放问题

- 菜单栏进程 PATH 不含 `~/.grok/bin`，必须写死常见安装路径。
- Gemini 本机未装，只验探测与未安装态。
- Carbon 热键、Safari 抓页、Developer ID 不在本任务。
