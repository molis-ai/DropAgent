# 切桌面后面板能在当前 Space 打开

## 背景目标

三指横滑换桌面后，菜单栏图标和开合快捷键在新桌面打不开面板。要能在当前桌面打开；不钉在第一次出现的那个 Space。

## 当前行为与问题证据

- 面板 `collectionBehavior` 是 `.canJoinAllSpaces + .fullScreenAuxiliary + .stationary`。`.stationary` 把窗口粘在首次出现的桌面；闲时再降到 `.normal` 后 `canJoinAllSpaces` 失效。
- App 是 `.accessory`：`makeKeyAndOrderFront` 不会把人带回旧 Space，也不会把窗口拽过来。
- `PanelIdle.toggle` 只看 `isVisible`，不看 `isOnActiveSpace`。窗口还在别的桌面时，点图标会 `wake` 或 `hide`，当前桌面没有反应。

## 范围与非目标

做：面板跟当前 Space 的挂接、开合判定、`showPanel` 在错桌面时先卸再挂。  
不做：进货 / Job / TUI / 抓页；不改闲时淡化规则；不改顶边轮盘（轮盘继续 `canJoinAllSpaces`）；切走后不自动把面板跟到新桌面。

## 使用场景

桌面 1 打开面板（或已经关掉）。横滑到桌面 2，点菜单栏图标或按开合快捷键：面板出现在桌面 2。再点一次才关掉。

## 方案与关键决策

- 打开时用 `.moveToActiveSpace + .fullScreenAuxiliary`，去掉 `.stationary` 和 `.canJoinAllSpaces`。
- 不在当前 Space：开合当成「打开」；`showPanel` 先 `orderOut` 再 `makeKeyAndOrderFront`。
- 切走后面板留在原桌面。新桌面再打开时把同一窗口挂过来。

## 输入输出与依赖

输入：`isVisible`、`isOnActiveSpace`、闲时态、图标/快捷键/`showPanel`。  
输出：当前 Space 上可见的面板。依赖现有 `DropAgentPanel` / `PanelIdle`。

## 文件 / 模块边界

- `macos/App/PanelIdle.swift`
- `macos/App/AppDelegate+Panel.swift`
- `macos/App/AppE2E.swift`
- `design/modules/app-shell.md`
- 本 spec

## 验收标准

1. `PanelIdle.toggle`：隐藏→开；当前桌面闲时→醒；当前桌面亮着→关；可见但不在当前 Space（闲时或亮着）→开。
2. `PanelIdle.spaceBehavior` 含 `.moveToActiveSpace` 和 `.fullScreenAuxiliary`，不含 `.stationary`、`.canJoinAllSpaces`。
3. `attachToActiveSpace`：不在当前 Space 时 `orderOut`；行为标志换成 `spaceBehavior`。
4. `swift build --product DropAgent`；`--e2e` 里 `verifyPanelIdle` 覆盖 1–3。
5. 真人：桌面 1 打开或关上面板，横滑到桌面 2，图标和开合快捷键能打开；再点关掉。

## 验证命令

```bash
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

真人横滑桌面无法在 e2e 里模拟，第 5 条人工验。

## 假设与开放问题

假设单屏多 Space。多显示器「各显示器独立 Space」未单独测。
