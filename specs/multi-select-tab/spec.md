# Command 多选不要把动作区切走

## 背景目标

Command 点是为了凑齐「新交付」或多发。现在点到已完成的条目，面板会跳到「结果」；动作区「对 N 项」按选中总数算，把已完成的也算进去。

## 当前行为与问题证据

`toggleSelect` 不论是否 Command，都按**刚点的那一条**切 Tab。预览 `13-multi` 里若再 Command 点 `summary.md`（可拖出），会离开 Recipe。`workBody` 用 `selectedItems.count` 写「对 N 项」，和 `recipeFitsSelection` 的可运行集合不一致。

## 范围

- Command 点：只改选择，不切 Tab。修饰键在 `leftMouseDown` 记下，松手点选时不读全局 `NSEvent.modifierFlags`，也不另加高优先级手势去抢行上拖出。
- 单击：仍按该条切到动作 / 终端 / 结果。
- Recipe 区「对 N 项」只数 idle / confirm / failed。
- 发送栏「N 项」仍是全部选中（已完成的也可以发给终端）。
- 预览：两份待处理已选中时再 Command 点一条已完成，仍停在「动作」。
- 粘贴 / 顶边进货后立刻 `refresh` 列表，不空一拍。

## 非目标

- Shift 连续选。
- Developer ID。

## 验收

1. 预览 `13c-keep-tab`：两份待处理 + 一份可拖出都在选择里，「动作」仍亮着；标题是「对 2 项」不是「对 3 项」；「新交付」可点。
2. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
```
