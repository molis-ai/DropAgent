# 终端不再叠输入框；已进终端仍显示动作

## 背景与目标

终端 Tab 已经是真正的 PTY，底下还挂着发给 TUI 的输入框，打两遍字。发给终端后，动作 Tab 变成「已进终端」海报，六个 Recipe 没了。架子上的材料还在，动作不该换掉。

## 范围

- `showsComposer` 只在动作 Tab 且点了「其他」时为真。终端 Tab 不显示 ComposerBar。
- 选中项全是 `.sent`：动作区仍是 Recipe 网格 + 「其他」，不再整页海报。
- `recipeBatch` / `chooseRecipe` 把 `.sent` 当成还能跑动作的材料。
- 不清系统剪贴板。不改四条调用链。

## 非目标

- 不改结果 Tab 的已进终端预览。
- 不把 done 的拿走态改回 Recipe。

## 使用场景

1. 发给 Grok 后在终端里打字，底下没有第二行输入框。
2. 再点「动作」：六个 Recipe 还在，可以总结这份已经进过终端的材料。

## 验收

1. `--e2e`：发送后 `aiTab == .tty` 且 `showsComposer == false`；切回动作，sent 的 PDF 仍 `recipeFitsSelection(.summarize)`。
2. Check 全绿。
