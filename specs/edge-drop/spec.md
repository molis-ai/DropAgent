# 顶边投放跟屏幕走，松手能进货

## 背景目标

菜单栏图标太小，全屏时还会藏起来。需求要求屏幕顶边也是进货口。现在条子只有屏幕中间 280pt，人拖到顶的左边或右边，看到条子却放不进去。松手那一下如果先把窗口收掉，drop 也会丢。

## 当前行为与问题证据

- `EdgePlacement.frame` 只要鼠标进了顶边 28pt 带，就在 `visibleFrame` 水平居中放一条 280×36 的窗口。鼠标不在这条上。
- 拖拽监视用 `Task { @MainActor in handleDrag }`，松手 `leftMouseUp` 立刻 `hideEdge()`。
- Check 不 import App，这条没有内核单测。

## 范围

- 顶边投放是贴着当前屏幕可见区域顶边的整条（左右各留 8pt），不是屏幕中间一块 280pt。
- 鼠标在哪块屏的顶边（可见区域顶往下 28pt 到屏幕顶），就亮哪条。
- 只有系统拖拽剪贴板里真有货（文件 / 图 / 字 / URL）才出现，避免点菜单栏时误亮。
- 拖拽事件在主线程立刻处理。松手落在条上时先别收，等 `draggingEnded` / `performDragOperation`；落在外面立刻收。
- 条子视觉跟面板同一套炭灰、1px 边、底圆角。Reduce Motion / `--preview` / `--e2e` 仍关掉入场动画。
- 不改四条调用链：顶边仍只 `Ingest.admit`（经 `admitPasteboard`）。

## 非目标

- Developer ID。
- 不解析 TUI、不模拟键盘。
- 不把顶边做成第二个面板。

## 使用场景

1. 从 Finder 拖一个 PDF 到屏幕顶边任意一处：出现顶边条，松手后 PDF 进架子；面板不因此打开或关掉。
2. 多屏：拖到右边那块屏的顶，条子在右边那块屏上。
3. 点菜单栏图标或拖窗口标题栏：顶边条不出现。

## 方案与关键决策

- `EdgePlacement.frame` 返回 `visibleFrame` 顶边整条（宽 = 可见宽 − 16，高 36）。
- `NSPasteboard(name: .drag)` 没货就不 `showEdge`。
- `leftMouseUp`：点在条上则等 drop 回调再收；否则立刻收。

## 输入输出与依赖

- 输入：全局 `leftMouseDragged` / `leftMouseUp`、拖拽剪贴板、`NSScreen` 几何。
- 输出：顶边窗口 frame；命中则 `admitPasteboard` + `showPanel`。
- 依赖：现有 `EdgeDropView`、`IncomingDrop`。

## 文件 / 模块边界

- 只改 `macos/App` 与本 spec。内核包不动。

## 验收标准

1. 顶边条宽度随屏幕可见区域走，不是固定 280pt 居中。`--e2e` 用当前 `NSScreen` 核对：顶边带命中框宽 = 可见宽 − 16，屏幕中间不命中。
2. 拖拽剪贴板为空时不出现顶边条。
3. 松手在条上会进货；不能因为先 `orderOut` 把 drop 吃掉。
4. Check 全绿；四条调用链不变。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

顶边投放需要从 Finder 拖到屏幕顶边亲手走一次（Check 不 import App）。

## 假设与开放问题

- 全局鼠标监视在本机普通权限下能收到 Finder 拖拽；若系统以后要求 Input Monitoring，失败时菜单栏图标仍是进货口。
