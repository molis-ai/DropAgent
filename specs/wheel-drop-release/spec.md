# 轮盘松手要进货

后续连续拖拽、移动中临时读空和面板边界修复见 [wheel-repeat-drag](../wheel-repeat-drag/spec.md)。成功投放的回执不再读取同步清理后的状态。

当前重叠区域的优先关系见 [wheel-finder-route](../wheel-finder-route/spec.md)：已经出现的轮盘在自身范围内拥有选择与投放，离开后才让给主面板。下文「松手在面板上」针对未被活动轮盘拥有的投放。

## 背景

从 Finder 把文件拖进轮盘一瓣再松开，轮盘消失，架子没有新条目。

## 根因

拖的过程里 `leftMouseDragged` 会把 payload 记进 `snapshot`。松手时轮盘窗口是投放目标：

1. `performDragOperation` 读到的 `draggingPasteboard` 经常已经空了（Finder 清过 `NSPasteboard.drag`）。
2. `admit` 遇到空 payload 直接返回，什么都不做。
3. `draggingEnded` 立刻 `finishExternalDrag` → `hide()`，把 snapshot 和拖拽板一起清掉。
4. 随后的 `mouseUp` / watchdog 再进货时已经没货。

和当年顶边条同一类问题，见 `specs/edge-drop-release/spec.md`。

## 范围

- `onPick`：板空则用 snapshot。
- `performDragOperation`：只有真正进货才返回 true；不要在这里 `hide`。
- `draggingEnded`：走 `finishFromMouseUp`（用 snapshot），不要先 `hide`。
- 同一次拖仍只进一次。不改调用链。
- 松手在面板上：轮盘不要抢、不要先清拖拽板。网页标签是承诺数据，板被清掉就进不了左列。面板 `admitDrop` 等 providers 读完再 `finishExternalDrag`。
- `hide()` 只有轮盘自己进了货才 `clearContents`；否则只记下 changeCount，避免同一趟拖再出轮盘。

## 验收

1. live 空、snapshot 有文件 → 用 snapshot。
2. 鼠标在面板上时，轮盘松手判定为交给面板，不按瓣进货。
3. Check 全绿；`swift build --product DropAgent`；`--e2e` 过。
4. Finder 拖 PDF 到「加入架子」松手：架子多一条。
5. 浏览器标签 / 链接拖到左列：进网站条。
