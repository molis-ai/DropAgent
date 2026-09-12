# 通用编码 TUI + 自定义命令 Runtime

## 背景目标

芯片里的纯 CLI 预置（LLM / AIChat / ShellGPT）不是编码 Agent，人用不上。设置里已经能「选可执行文件」当 Runtime，但不能直接写命令名。要能输入 `kimi` 这类命令当 Runtime，并补上本机常见的编码 TUI。

## 当前行为与问题证据

- 预置纯 CLI：`llm` / `aichat` / `sgpt`。本机有才出现，auto 在没 TUI 时落到它们。
- 自定义 Runtime 只能 `NSOpenPanel` 选文件，不能写 `kimi` 或路径。
- 芯片没有 Kimi Code / CodeBuddy / Qwen Code。

本机核查（2026-09-12）：

| 用户说的 | 实际 | 处理 |
|---|---|---|
| KimiCode | 官方 Kimi Code CLI，命令 `kimi`（也有 `kimi-code`），TUI；无界面 `kimi -p` / `--prompt` | 预置 TUI，芯片 **Kimi Code** |
| Workbuddy | 腾讯 CodeBuddy CLI，命令 `codebuddy` / `cbc`；WorkBuddy 桌面会带一份 CLI。TUI；无界面 `-p` / `--print` | 预置 TUI，芯片 **CodeBuddy**；探测 PATH 和 WorkBuddy.app 里那份 |
| Zcode | 官方是桌面 ADE，没有第一方 TUI。`zcode` 是第三方从桌面抽 runtime | **不预置**。有的人可用自定义命令加上 |
| deepseek | 官方 `dsh` 是 harness：默认 web / headless，TUI 要另装插件，且常是 `npx … --profile tui` | **不预置**。第一版命令不加参数 |
| （额外）Qwen Code | 官方终端 Agent，命令 `qwen`，Gemini CLI 分支；无界面 `qwen -p` | 预置 TUI，芯片 **Qwen Code** |

## 范围

- 去掉预置 `llm` / `aichat` / `sgpt`。旧设置里 `tuiEngine` 是这三项的，读成 `auto`。人若还用这些命令，用自定义命令加上，并标成 CLI。
- 预置 TUI 增加 **Kimi Code**（`kimi`、`kimi-code`）、**CodeBuddy**（`codebuddy`、`cbc`，含 WorkBuddy.app 内置路径）、**Qwen Code**（`qwen`）。auto 仍先原来六家：Grok → Claude → Gemini → OpenCode → Cursor CLI → Codex → Kimi Code → CodeBuddy → Qwen Code。
- 设置 Runtime：输入命令名或可执行文件路径，回车或点添加。仍可「选择可执行文件…」。只解析第一个 token，不要 `npx foo --profile tui`。
- 写的命令若能认出是预置，走该引擎覆盖路径；否则追加自定义 Runtime。同一路径不重复添加。找不到则在 Runtime 区块说明，不写进列表。
- 发送 / Recipe 跟芯片。Kimi / CodeBuddy / Qwen 档位仍是「在终端执行，不是副本沙箱」。**不**设 `KIMI_CODE_HOME` 等假 home，以免丢掉登录。不传 `--yolo` / `--dangerously-skip-permissions` / `--auto`。
- 启动参数只按官方文档和本机 `--help`：
  - Kimi 发送：把那句话当 argv（不要 `-p`，`-p` 会关掉 TUI）。动作：`--prompt` / `-p`。
  - CodeBuddy 发送：`codebuddy "…"` 进 REPL。动作：`--print` / `-p`。
  - Qwen 发送：与 Gemini 一样 `--prompt`。动作：`--prompt` / `-p`。
- 自定义 CLI（人自己加、标成 CLI）仍走默认 shell 打一条命令。

## 非目标

- 不预置 ZCode、DeepSeek / `dsh`。
- 不接云端 API Key、Ollama。
- 不解析 TUI、不模拟按键点菜单。
- 第一版不把带参数的命令（`npx @deepseek-ai/dsh --profile tui`）存成 Runtime。
- 不发明未经 `--help` 证明的 flag。
- 不改进货链。不 commit / push。

## 使用场景

1. 装了 `kimi`。芯片出现 Kimi Code。auto 若已有 Grok，仍是 Grok。人手动选 Kimi Code，发送进 Kimi TUI，不带 `-p`。点翻译且 `--help` 有 `--prompt`：`kimi --prompt '…'`。
2. 只装了 WorkBuddy 桌面、PATH 里没有 `codebuddy`。仍能发现 app 里那份 CLI，芯片写 CodeBuddy。
3. 设置输入 `qwen`，本机有 `~/.local/bin/qwen`：当成 Qwen Code，不必再选文件。
4. 设置输入 `dsh` 且 PATH 上有：自定义 Runtime（默认 TUI，可改成 CLI）。输入 `dsh --profile tui`：提示只写命令本身。
5. 输入 `llm`：自定义项，人标成 CLI 后发送走 shell。

## 方案与关键决策

- `AgentEngine` 去掉三个纯 CLI，加上 `kimi` / `codebuddy` / `qwen`。`AgentSettings.tuiEngine` 用字符串解码，未知值（含旧 `llm`）当 `auto`。
- 新类型 `RuntimeCommand`：解析、在 PATH 与常见目录里解析可执行文件。App 设置调用它，再 `adoptExecutable`。
- CodeBuddy 额外目录：`/Applications/WorkBuddy.app/Contents/Resources/app.asar.unpacked/cli/bin` 与 `~/Applications/…` 同路径。
- 识别靠文件名：不要用 help 里出现 “Kimi” 把 Qwen 认成 Kimi（Qwen 登录项会提到 Kimi）。
- 芯片菜单：cliCases 空则不画那一段分隔线。自定义 CLI 仍出现。

## 输入输出与依赖

输入：PATH、常见安装目录、WorkBuddy 内置 CLI、设置覆盖路径、自定义列表、命令输入、该二进制 `--help`、发送文本、副本 cwd。  
输出：芯片列表、`tuiPresence` / `recipePresence`、TUI argv 或 shell 命令、Job argv、设置错误说明。  
依赖：现有链 B / C、隔离 home、Job `work/` `output/`。

## 文件 / 模块边界

- `01-requirements.md`、`02-prototype-design.md`、`03-tech-architecture.md`
- `design/modules/agent.md`、`tui.md`、`ai-pane.md`、`README.md`
- `macos/Packages/DropAgentAgent/`、`DropAgentTUI/`
- `macos/App/SettingsRuntime.swift`、`AppSession+Settings.swift`、`PanelHeader.swift`
- `macos/Check/main.swift`
- `prototype/index.html` 芯片名单跟上

## 验收标准

1. Check：同时有 Grok 与 `kimi` 时 auto 仍是 Grok。强制 Kimi / CodeBuddy / Qwen 时 presence 对得上。
2. Check：`identified("kimi")` / `kimi-code` → Kimi；`codebuddy` / `cbc` → CodeBuddy；`qwen` → Qwen。help 含 Kimi 的 `qwen` 仍是 Qwen。
3. Check：Kimi Job 用 `--prompt` 或 `-p`，不含 `--yolo`。Kimi TUI argv 含那句话，不含 `-p`。
4. Check：CodeBuddy Job 用 `--print` 或 `-p`，不含 `--dangerously-skip-permissions`。Qwen Job 用 `--prompt` 或 `-p`，不含 `--yolo`。
5. Check：`RuntimeCommand.parse("kimi -p hi")` 失败；`kimi` 能在 PATH 目录解析到可执行文件。
6. Check：旧 JSON `{"tuiEngine":"llm"}` 解码为 `auto`。
7. Check：自定义 `kind: .cli` 发送仍是 shell `-l`、`feedOnLaunch`、injection 是命令、不含原件路径。
8. 设置能输入命令添加；找不到时列表不变。选文件仍可用。
9. 芯片与文档不再出现 LLM / AIChat / ShellGPT。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
```

## 假设与开放问题

- 本机未装这些 CLI：用桩二进制测参数，不跑真模型。
- Kimi 交互是否把无 `-p` 的位置参数当第一句：按 Cursor 同样处理；若某版忽略该参数，人仍可在已打开的 TUI 里打字。
- ZCode / DeepSeek 以后若出官方单命令 TUI，再单独立项，不在这次发明 `npx` 命令行。
