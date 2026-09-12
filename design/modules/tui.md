# 模块：TUI

包：`DropAgentTUI`

## 做什么

把选中条目的**副本路径**和用户输入框里的字，投进本机 Agent 的交互式会话。面板底部嵌入 PTY 只是显示该会话，不另开桌面窗口。

## 不做什么

不 OCR、不解析 TUI 画面、不模拟鼠标点终端菜单。不把用户原件路径打进会话。不在无 Agent 时假装成功。

## Public

```text
send(itemIDs: [ItemID], text: String, sessionDirectory: URL?) throws -> PreparedTUISend
revertSend(itemIDs: [ItemID])
```

PTY 由 App 的 `TerminalHostView` 嵌进「终端」Tab，不在本包。`text` 可为空：只把文件副本路径作为材料送入（用户「拖到下面」没打字）。

材料：对每个 Item，使用 Inbox/Jobs 里已有副本；若还没有副本，TUI 先做一次与 Job 相同的安全复制到 `TUIInbox/<id>/`，再引用这些路径。禁止直接把 Desktop 原路径 paste 进会话。

终端引擎由 `Agent.tuiPresence` 决定。TUI（Grok / Claude / Gemini / OpenCode / Cursor CLI / Codex / Kimi Code / CodeBuddy / Qwen Code / 自定义 TUI）把副本路径和文本送进交互会话。自定义纯 CLI 在默认 shell 里发出译好的命令，不假装内嵌 Agent 画面。隔离 home：Codex 用 `CODEX_HOME`，Grok 用 `GROK_HOME`（拷 `auth.json`；首次种子 `config.toml` 可带用户已确认的 `privacy_banner_acked`，不拷 MCP / always-approve），Claude 用 `CLAUDE_CONFIG_DIR` + 空 MCP，OpenCode 用空的 `OPENCODE_CONFIG_DIR`。Kimi / CodeBuddy / Qwen / Cursor 不伪造登录 home。不加载用户全局 MCP / Hooks。

## 调用

`Agent.ensureInteractiveSession`；`prepare` 时拷登录态；成功后 `Shelf.patch(..., status: .sent)`。PTY 拉起失败由 App 调 `revertSend`。

## 失败

没有 TUI、可执行文件不存在或不可执行、材料为空：抛错，条目保持 idle，App 说人话。先确认可执行文件，再复制并标 `.sent`。
