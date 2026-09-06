# 终端拉不起来时条目保持待处理

## 背景目标

`design/modules/tui.md`：会话拉不起来或可执行文件消失时抛错，条目保持 idle。现在 `send` 在拷贝后立刻标 `.sent`，PTY 还没起来。

## 当前行为与问题证据

`TUIService.send` 在 `ensureInteractiveSession` 之后就 `patch(.sent)`。FakeAgent 可以指向不存在的路径，条目仍会变成已进终端。

## 范围

- `send` 在复制和改状态之前检查可执行文件存在且可执行。失败抛 `TUIError.launchFailed`，条目仍 idle。
- App 启动 PTY 前再查一次；没有文件则把刚标成 sent 的条恢复 idle，并说「没能打开 {引擎} 终端。」
- 正常用完 Grok 退出仍保持 `.sent`。

## 非目标

- 不解析 TUI 画面。
- 不把 Recipe 接到 Grok。

## 验收

1. Check：指向不存在二进制的 `send` 抛错，条目 idle。
2. `/usr/bin/true` 的现有 TUI 单测仍过。
3. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
```
