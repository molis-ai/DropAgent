# 模块：AI Pane（App 内 UI，不是独立内核包）

代码位置：`macos/App/PanelRootView.swift`（动作区在同一面板里，不是独立包）。规则仍来自 Job / TUI / Agent，这里只规定界面状态和动线。

## 做什么

面板下半：动作 / 终端 / 结果三个 Tab、六个 Recipe、输入框、粘贴、发送。把用户操作转成 Job.start 或 TUI.send。

## 不做什么

不自己发现 `codex` / `grok`（问 Agent.tuiPresence / recipePresence）。不在前端发明「拖到下面等于 Recipe」。头上芯片打开终端引擎菜单。

## 三个 Tab

| Tab | 何时出现内容 |
|-----|----------------|
| 动作 | 默认。六个 Recipe。无 Codex 时 Recipe 禁用；无 TUI 时发送禁用，留安装引导。选中已完成、或失败但已有 output：不画 Recipe，指向拿走；后者可「再跑一次」。 |
| 终端 | 内嵌 PTY。发送后自动切到这里。 |
| 结果 | Job 完成后自动切到这里。未跑也可以：网站、图片、CLIP、链接、文稿、文件夹、其他文件点开看；PDF / 其他文件说明拖出打开。只读。正文可滚；拖出 / 复制（有会话再加终端）钉在输入框上方。 |

## 输入与发送

- 输入框 = 给 TUI 的那句话，不是 Recipe 的隐藏 Prompt。  
- 发送 / 拖入 AI 区：有选中或刚落入的条目 + 框里的字（可空）。  
- 粘贴按钮 / ⌘V：走 Ingest，条目进**列表**，不自动发送。

## Recipe 确认

点 Recipe → 条目 `confirm` → 动作区显示权限四行和「在副本中运行 / 取消」→ 确认才 `Job.start`。文件行只标「未运行」，不把确认按钮放在行上。

## 扩展

新 Recipe 按钮只映射到新的 RecipeID。布局改动不改变调用链。
