# 再点取消选中，双击打开

## 背景与目标

文件和结果卡单击只负责选中。需要：已选中的再点一次取消选中；双击用系统默认方式打开文件、结果或链接。

完成等级：功能可用。

## 当前行为与问题

- 文件：`ShelfStore.toggleSelect` 单独再点会清空，但卡片若把「选中」也推迟到双击间隔之后，动作栏会慢半拍。
- 结果：若 `selectResult` 本身切换选中，键盘停在当前条、e2e 再选同一条都会误取消。
- 双击：应打开系统默认 App，不要在面板里假装预览。

## 范围

- 文件卡、结果卡的单击 / 双击。
- 打开：结果用 `output`；网站和链接用可打开的 `http(s)`；其余用架子上的副本。不打开 `javascript:`。文件不存在则报错。
- e2e 只断言将打开的 URL，不真的拉起外部 App。

## 非目标

- 不改内核业务规则，不覆盖原件。
- 双击不隐藏面板，不在面板内嵌打开。
- 不改 Command 多选。

## 方案

- 未选：第一次单击立刻选中。
- 已选：第一次单击等过双击间隔再取消；若期间第二次单击，则打开并保持选中。
- 当前焦点在结果区时，文件卡看起来没选中；再点该文件是选中，不是取消。
- `selectResult` 始终选中（键盘 / 程序）。卡片走 `toggleResult`。
- `openItem` 解析 URL 后 `NSWorkspace.shared.open`。

## 验收

1. 点未选文件：立刻选中，动作栏出现。
2. 再点已选文件（不是双击）：取消选中，动作栏消失。
3. 焦点在结果时点文件：选中该文件，不因架子里还记着它而取消。
4. 双击文件 / 结果 / 链接：系统默认方式打开，选中保持。
5. 结果区键盘停在当前条：不会取消选中。
6. `javascript:` 和失踪文件打不开，给出错误文案。
7. `swift run DropAgentCheck` 与 `--e2e` 通过。

## 验证

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```
