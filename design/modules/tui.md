# 模块：TUI

包：`DropAgentTUI`

## 做什么

把选中条目的**副本路径**和用户输入框里的字，投进本机 Agent 的交互式会话。面板底部嵌入 PTY 只是显示该会话，不另开桌面窗口。

## 不做什么

不 OCR、不解析 TUI 画面、不模拟鼠标点终端菜单。不把用户原件路径打进会话。不在无 Agent 时假装成功。

## Public

```text
send(itemIDs: [ItemID], text: String) async throws
attachPTY(into view:)   // App 调用，把会话嵌进「终端」Tab
```

`text` 可为空：只把文件副本路径作为材料送入（用户「拖到下面」没打字）。

材料：对每个 Item，使用 Inbox/Jobs 里已有副本；若还没有副本，TUI 先做一次与 Job 相同的安全复制到 `TUIInbox/<id>/`，再引用这些路径。禁止直接把 Desktop 原路径 paste 进 Codex。

## 调用

`Agent.ensureInteractiveSession`；成功后 `Shelf.patch(..., status: .sent)`。

## 失败

会话拉不起来、可执行文件消失：抛错，条目保持 idle，App 说人话。
