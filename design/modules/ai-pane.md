# 模块：AI Pane（App 内 UI，不是独立内核包）

代码位置：`macos/App/AIPane.swift`（`WorkPane` / `ResultPane` / `ResultPreview` / `ComposerBar`；`PanelRootView` 只拼装左右栏）。规则仍来自 Job / TUI / Agent，这里只规定界面状态和动线。

## 做什么

面板右侧：动作 / 终端 / 结果三个 Tab、六个 Recipe、输入框、粘贴、发送，composer 上方的结果栈。把用户操作转成 Job.start 或 TUI.send。点左列看输入；点结果栈看产出。

## 不做什么

不自己发现 `codex` / `grok`（问 Agent.tuiPresence / recipePresence）。不在前端发明「拖到右边等于 Recipe」。头上芯片打开 Runtime 菜单（预置 TUI、预置 CLI、自定义）。

## 三个 Tab

| Tab | 何时出现内容 |
|-----|----------------|
| 动作 | 默认。六个 CLI Recipe 横排；选中都是图片或都是 PDF 时出现「文字提取」。栏最前可整理（藏、换序），最后加号加快捷动作（类型 + Prompt，Job 产出 `原名-动作.md`，发给当前芯片）。「其他」钉在加号前，打开对话。芯片对应 CLI 没有可收口入口时 CLI Recipe 与快捷动作禁用；「文字提取」不依赖 CLI。无 TUI 时发送禁用，留安装引导。旧数据里选中已完成、或失败但已有 output：不画 Recipe，指向拿走；后者可「再跑一次」。新 Job 跑完输入仍是 idle，动作区仍是 Recipe。已进终端的条目同样留着这列动作。 |
| 终端 | 内嵌 PTY。发送后自动切到这里。不显示底下输入框，在终端里打字。焦点在结果栈时发送该产出文件，不把左列标成 sent。 |
| 结果 | Job 完成后自动切到这里并选中新产出。未跑也可以：网站、图片、CLIP、链接、文稿、文件夹、其他文件点开看；HTML 抽成可读正文（不是网页预览）；PDF / 其他文件说明拖出打开。只读。正文可滚；拖出 / 复制（有会话再加终端）钉在输入框上方。选中文件时，内容台在文件列表和动作栏之间展示正文。 |

## 输入与发送

- 输入框只在动作 Tab 点了「其他」时出现：给 TUI 的那句话，不是 Recipe 的隐藏 Prompt。终端 Tab 不画这行。  
- 发送 / 拖入 AI 区：有选中或刚落入的条目 + 框里的字（可空）。  
- ⌘V：走 Ingest，条目进**列表**，不自动发送。对话浮窗不放粘贴按钮。

## Recipe 确认

点 Recipe → 条目 `confirm` → 动作区显示权限四行和「在副本中运行 / 取消」→ 确认才 `Job.start`。文件行只标「未运行」，不把确认按钮放在行上。

## 扩展

新 Recipe 按钮只映射到新的 RecipeID。布局改动不改变调用链。
