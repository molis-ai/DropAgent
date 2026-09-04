# 模块：AI Pane（App 内 UI，不是独立内核包）

代码位置：`macos/App/AIPane/`。规则仍来自 Job / TUI / Agent，这里只规定界面状态和动线。

## 做什么

面板下半：动作 / 终端 / 结果三个 Tab、六个 Recipe、输入框、粘贴、发送。把用户操作转成 Job.start 或 TUI.send。

## 不做什么

不自己发现 `codex`（问 Agent.discover）。不在前端发明「拖到下面等于 Recipe」。

## 三个 Tab

| Tab | 何时出现内容 |
|-----|----------------|
| 动作 | 默认。六个 Recipe。无 Agent 时 Recipe 禁用，留安装引导。 |
| 终端 | 内嵌 PTY。发送后自动切到这里。 |
| 结果 | Job 完成后自动切到这里；可点开预览（只读）。 |

## 输入与发送

- 输入框 = 给 TUI 的那句话，不是 Recipe 的隐藏 Prompt。  
- 发送 / 拖入 AI 区：有选中或刚落入的条目 + 框里的字（可空）。  
- 粘贴按钮 / ⌘V：走 Ingest，条目进**列表**，不自动发送。

## Recipe 确认

点 Recipe → 条目 `confirm` → 条上显示「确认 / 取消」和隔离档原文 → 确认才 `Job.start`。

## 扩展

新 Recipe 按钮只映射到新的 RecipeID。布局改动不改变调用链。
