# 设置分栏与权限判定

## 目标

设置左右分栏、五个大类。抓页「准备好」不再要求所有已装浏览器都授权。静默探测未允许时显示未询问，不当成已拒绝。

## 行为

- 左：使用准备、快捷键、能做什么、本机、外观。右：该类内容。默认使用准备。
- 设置里的使用准备不再重复三条全局快捷键状态（改快捷键在「快捷键」）。第一次打开的清单仍含快捷键占用。
- `captureReady`：辅助功能已开，且至少有一家浏览器已允许（没有浏览器行则只看辅助功能）。
- 齿轮小点：没 Agent，或辅助功能没开，或已装浏览器里一家都没允许。
- `AutomationAccess.probe`：静默得到 denied 时按 notDetermined。真正去授权仍用会弹对话框的 request。

## 验收

1. Check：Safari 已允许、Chrome 未询问 → captureReady 为真。
2. Check：仅 Safari 未询问 → captureReady 为假。
3. Check：静默 denied 的 probe 为 notDetermined；`state(from: notPermitted)` 仍是 denied。
4. e2e：设置英文下能切到 Shortcuts / What it can do 并看到对应正文。
5. `swift run DropAgentCheck`；`swift build --product DropAgent`。
