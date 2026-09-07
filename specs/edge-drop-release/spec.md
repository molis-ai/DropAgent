# 顶边条子松手要进货

## 背景与目标

从 Finder 拖文件到屏幕顶边黑条，松手没有进架子、面板也不开。条子已经亮了，说明拖拽监视有货；真正的 drop 没落到窗口上，拖拽剪贴板在 mouseUp 时又已经被清空。

## 当前行为

- 顶边是普通 `NSWindow`，只靠 view `registerForDraggedTypes`。Finder 跨进程拖放经常进不来 `draggingEntered` / `performDragOperation`。
- `ClipboardPayload.from` 只用 `readObjects(NSURL)`；Finder 常用 `NSFilenamesPboardType`。
- 松手时 live 剪贴板已空、snapshot 也空，只能等 drop 回调，回调不来就什么都不做。

## 范围

- 顶边改成 `NSPanel`（`.nonactivatingPanel`），窗口自己也注册拖放类型，`sharingType = .readWrite`。拖的时候升到比菜单栏高一层，松手再降回。
- `ClipboardPayload.from` 增加 `NSFilenamesPboardType` 和 file-url 字符串。
- 拖的过程中把读到的 payload 存进 snapshot；松手在条上时用 snapshot 进货。窗口先别 `orderOut`。
- Finder 拖放经常没有 `leftMouseUp`。左键已经松开时用 watchdog 结束拖拽层，避免「加入架子 / 发给 Grok」卡住。面板 `onDrop` 和顶边 drop 都调用 `finishExternalDrag`。
- 不改四条调用链。

## 验收

1. Finder 拖 PDF 到顶边黑条松手：进架子；面板不因此打开或关掉。
2. Check：filenames 剪贴板能解析成 files。
3. e2e 顶边几何仍过。

## 验证

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```
