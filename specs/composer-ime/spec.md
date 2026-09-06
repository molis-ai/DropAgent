# 输入法回车确认候选时不要发送

## 背景目标

给 Grok 的那一行用 SwiftUI `TextField.onSubmit`。中文输入法按回车是确认候选，不是发送。现在会把半成品打进终端。

## 当前行为与问题证据

`PanelRootView` 作曲家：`.onSubmit { session.sendToTUI() }`。有 marked text 时回车仍提交。

## 范围

- 输入框改成 `NSTextField`。回车且没有 marked text 才 `sendToTUI`。
- 有候选时把回车交给输入法。
- 外观仍走白底、发丝边；聚焦时墨色描边。占位文案不变。
- 发送按钮、拖到 AI 区不受影响。

## 非目标

- 不多行输入、Shift+Enter 换行。
- Developer ID。

## 验收

1. 预览 01/03/08 输入框仍在，占位还是「写给 Grok…」。
2. Check 全绿。
3. 构建 DropAgent 通过。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
```
