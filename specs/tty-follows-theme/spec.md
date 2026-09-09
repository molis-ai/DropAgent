# 终端底色跟外观

## 背景与目标

打开对话里的终端后，底色写死近黑。浅色主题下是一块黑壳。要：浅色白底终端，深色黑底终端。

完成等级：功能可用。

## 当前行为

`Palette.ttyWell` / `ttyWellNS` 固定 23 灰。空井还用 OSC `#171717` 填屏。

## 范围

- 终端井、空状态遮罩、SwiftTerm 默认前景/背景/光标。
- 外观切换时已打开的终端也改默认色，不清掉会话内容。

## 非目标

- 不改 Agent 自己画的 TUI 主题（Grok 等可能仍用自家配色）。
- 不改 Recipe / 进货。

## 方案

- `ttyWell` / `ttyInk` 跟 `Palette.isDark`。
- 空井：浅 `#fcfcfd`，深 `#171717`。
- 会话中只发 OSC 10/11，不 `2J`。

## 验收

1. 浅色：终端井接近纸白，字深色。
2. 深色：终端井近黑，字浅色。
3. 切换外观时井跟着变。
4. `swift run DropAgentCheck` 与 `--e2e` 通过。

## 验证

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```
