# 面板失去 key 后第一下要点中；作曲家聚焦才是墨边

## 背景目标

拖出到 Finder 时面板不能先消失（`hidesOnDeactivate = false`）。人点完桌面再点 Recipe / 发送 / 输入框，第一下经常只是让面板变成 key，动作没发生。作曲家 spec 要求聚焦时墨色描边，但描边绑在 SwiftUI `FocusState` 上，点 `NSTextField` 时经常不更新。

## 当前行为与问题证据

- 正式面板是 borderless `NSPanel`，内容是 `NSHostingView`。系统默认 `acceptsFirstMouse == false`：非 key 窗口的第一次点击只激活窗口。
- `ComposerField` 外面包着 `.focused($composerFocused)`。真正成为 first responder 的是 field editor，SwiftUI 状态经常仍是 false，描边停在发丝。

## 范围

- 面板用的 hosting view：`acceptsFirstMouse` 为真。
- 作曲家 `NSTextField`：同样接受第一下；开始编辑墨边，结束编辑发丝边。
- `--e2e` 断言 hosting view 接受 first mouse；borderless 仍可成为 key。
- 不改四条调用链，不改 `hidesOnDeactivate`。

## 非目标

- Developer ID。
- 不把面板改成点外面就关。
- 不自动聚焦作曲家。

## 使用场景

把 `summary.md` 拖到桌面后，面板还在。立刻点「总结」或点输入框：第一下就生效，输入框出现墨边。

## 方案与关键决策

`NSHostingView` 子类只改 first mouse。聚焦状态只听 `NSTextField` 的 begin/end editing，不再用 `.focused` 猜。

## 输入输出与依赖

输入：非 key 的面板、点击、输入法。输出：第一下命中控件；描边跟 first responder。依赖现有 `DropAgentPanel`。

## 文件 / 模块边界

- `macos/App/Palette.swift`
- `macos/App/AppDelegate.swift`
- `macos/App/ComposerField.swift`
- `macos/App/PanelRootView.swift`
- `macos/App/PanelPreview.swift`
- `macos/App/AppE2E.swift`
- 本 spec

## 验收标准

1. 面板 hosting view `acceptsFirstMouse(for:)` 为真。
2. `--e2e`：borderless 仍可 become key；hosting view 接受 first mouse。
3. 预览 `01-empty` / `03-idle` 输入框仍在，占位不变。
4. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

锁屏时 Safari 不能到最前，`--e2e` 抓页仍会失败，见 `capture-app-e2e`。
