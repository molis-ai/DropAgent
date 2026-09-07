# 额外 Runtime：OpenCode / Cursor CLI / 常见 CLI / 自定义

## 背景目标

芯片列表不要写死四家。先接**带 TUI 的**（OpenCode、Cursor CLI），设置里能添加自定义可执行文件，加完立刻出现在芯片列表。若这是**纯 CLI**（没有 Agent 画面），不要假装内嵌 TUI：把用户那句话译成一条常规命令，在面板终端 Tab 里用默认 shell 发出去。

## 当前行为与问题证据

- 引擎枚举只有 Grok / Claude / Gemini / Codex。
- 设置页没有添加 Runtime。`指定可执行文件` 只按文件名把 `agent` 当成 Grok；本机 `~/.grok/bin/agent` 是 Grok Build TUI，Cursor 官方安装名常是 `cursor-agent`，也可能叫 `agent`。
- 发送一律按 TUI 拼启动参数。纯 CLI 没有内嵌画面可开。

## 范围

- 预置 TUI：现有四家 + **OpenCode**（`opencode`）+ **Cursor CLI**（优先 `cursor-agent`；文件名 `agent` 必须用 `--help` 区分，且不要把 `~/.grok/bin/agent` 认成 Cursor）。芯片文案写 **Cursor CLI**，避免以为会弹出 Cursor 窗口。
- 预置纯 CLI（本机有才出现）：`llm`、`aichat`、`sgpt`。自动探测顺序仍优先 TUI；只有没装 TUI 时 auto 才落到 CLI。
- 设置里添加 / 删除自定义 Runtime（名字 + 可执行文件 + TUI / CLI）。芯片列表 = 预置 ∪ 自定义。
- **TUI 芯片**：发送仍走链 C，内嵌 PTY 拉起该 TUI。OpenCode：`opencode <副本目录> --prompt …`，隔离配置目录，不传 `--auto`。Cursor CLI：把那句话当作交互会话的初始 prompt，不传 `--force` / `--yolo`。
- **CLI 芯片**：发送仍走链 C 的终端 Tab，但进程是默认 shell（`SHELL`，没有则 `/bin/zsh`）`-l`，cwd 是材料副本目录，再把译好的命令打进去。例如 `llm '…'`。不打开 Terminal.app。
- Recipe 仍走链 B。TUI 且 `--help` 有收口入口才启用（OpenCode：`run`；Cursor：`-p` / `--print`）。纯 CLI 本身就是一发一收，动作用同一条命令在 `work/` 跑，结果写 `output/`。没有证据的 flag 不发明。不传 `--auto` / `--yolo` / `--dangerously-skip-permissions` / `--always-approve`。
- 文件名 `agent` 的身份以 `--help` 为准：含 `Grok Build` → Grok；含 Cursor 且路径不在 `~/.grok/` → Cursor CLI。

## 非目标

- 不接 Ollama / 云端 API Key。
- 不覆盖用户原文件；Prompt 不写原件路径。
- 不解析 TUI、不模拟按键。
- 不把 `--auto` / `--yolo` 当跳过授权。
- 不为没装的工具造假已连接。
- 不改四条进货链。不 `commit` / `push`。

## 使用场景

1. 装了 `opencode`，芯片选 OpenCode。选 `notes.md`，输入「哪几条不能对外说」，发送：

```
opencode /…/TUIInbox/session --prompt "请阅读当前目录中的副本材料…"
```

不带 `--auto`。点翻译且 `opencode --help` 有 `run`：

```
opencode run --dir /…/Jobs/<id>/work $'阅读当前工作目录里的材料。…'
```

2. 装了 `cursor-agent`。芯片写 Cursor CLI。发送把那句话当作交互初始 prompt。本机若只有 `~/.grok/bin/agent`（Grok Build），芯片里不会出现 Cursor CLI。

3. 设置里选 `~/.local/bin/llm`，标成 CLI。芯片出现 LLM。发送打开 zsh，cwd 是副本目录，打出：

```
'/Users/me/.local/bin/llm' '请阅读当前目录中的副本材料…
- notes.md
用户说：
翻译成中文'
```

点翻译则 `llm` 在 `work/` 跑同一段 Recipe Prompt，stdout 写 `output/translated.md`。

4. 自定义 TUI：选一个未知二进制、标成 TUI → 芯片出现该名字，发送把那句话当参数拉起它。

## 方案与关键决策

- `AgentEngine` 增加 `opencode` / `cursor` / `llm` / `aichat` / `sgpt`。`AgentSettings.customRuntimes` 存用户添加的项；`selectedCustomID` 选中自定义。
- auto：Grok → Claude → Gemini → OpenCode → Cursor CLI → Codex，再才是纯 CLI。
- CLI 发送：`PreparedTUISend.feedOnLaunch = true`，PTY 先起 shell，再把命令当键盘输入送进去（和 TUI 把 prompt 放进 argv 不同）。
- 隔离：OpenCode 用空的 `OPENCODE_CONFIG_DIR`，登录态仍走用户 `~/.local/share/opencode/auth.json`（不改 HOME）。Cursor CLI / 纯 CLI 不伪造 HOME。档位仍是「在终端执行」或「未确认」，不把 Codex Workspace 套上去。
- 引号：POSIX 单引号，`'` → `'\''`。

## 输入输出与依赖

输入：PATH / 常见安装目录、设置里的覆盖路径和自定义列表、该二进制 `--help`、发送文本、副本 cwd。  
输出：芯片列表、`tuiPresence` / `recipePresence`、TUI argv 或 shell 命令行、Job argv。  
依赖：现有链 B / C、隔离 home、Job `work/` `output/`。

## 文件 / 模块边界

- `01-requirements.md`、`02-prototype-design.md`、`03-tech-architecture.md`
- `design/modules/agent.md`、`tui.md`、`ai-pane.md`
- `macos/Packages/DropAgentAgent/`、`DropAgentTUI/`
- `macos/App/SettingsPane.swift`、`AppSession.swift`、`PanelRootView.swift`、`AppDelegate.swift`、`TerminalHostView.swift`
- `macos/Check/main.swift`
- `prototype/index.html` 芯片菜单跟上，不发明内核没有的规则

## 验收标准

1. Check：同时有 `grok` 与 `opencode` 时 auto 仍是 Grok。强制 OpenCode 时 `tuiPresence` 是 OpenCode。
2. Check：`~/.grok/bin/agent` 且 help 含 Grok Build → 不是 Cursor。`cursor-agent` 且 help 含 Cursor → Cursor CLI。
3. Check：OpenCode TUI 参数含 `--prompt` 和副本目录，不含 `--auto`。Job 是 `run`，不含 `--auto`。
4. Check：Cursor TUI 参数不含 `--yolo` / `--force`。Job 用 `-p` 或 `--print`。
5. Check：CLI 发送可执行文件是 shell、参数 `-l`、injection 是引号包好的命令、不含原件路径、`feedOnLaunch` 为真。
6. Check：自定义 Runtime 出现在 `installedEngines`，选中后 `tuiPresence` 是它。
7. 设置页能添加 / 删除 Runtime；芯片菜单立刻出现。预览能打开设置看到这一块。
8. 四条进货链与原件 Hash 约定不变。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
```

## 假设与开放问题

- 本机未装 `opencode` / `cursor-agent` / `llm`：用桩二进制测参数，不跑真模型。
- Cursor 官方文档里交互入口叫 `agent`；实现以 `cursor-agent` 为主，`agent` 必须过指纹。
- 默认终端 = 面板里的登录 shell，不是系统 Terminal.app。
