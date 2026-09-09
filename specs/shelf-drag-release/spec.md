# 从架子拖回架子：松手不复制

## 背景与目标

架子上的文件拖出去再在「加入架子」处松手，会再进一条副本。人只是没拖到别处，应该直接放下，架子不变。

完成等级：功能可用。

## 当前行为

`FileCard.onDrag` 交出 Inbox 文件 URL。松手到文件行走 `admitDrop`，Ingest 再复制一份。Shelf 允许同一 `sourceURL` 出现多次。`lastInternalDropAt` 只挡 0.35 秒内的第二次进货，挡不住这次。

Finder 连拖两次仍应是两条。结果卡拖到文件行仍可当材料进货。

## 范围

- 文件行、菜单栏图标、轮盘「加入架子」：来自架子的拖放不进货。
- 轮盘「发给」/ Recipe、对话浮窗：用正在拖的那几条，不再复制。
- 拖到桌面 / 别的 App 不变。

## 非目标

- 不改内核「同一 sourceURL 可重复」；那是 Finder 连拖两次。
- 不覆盖原件。

## 方案

- 文件卡开始拖时记下条目 id，并在拖放剪贴板打内部标记。
- `admitDrop` / `admitPasteboard` / 轮盘加入架子：有标记则直接结束拖放。
- 鼠标抬起后下一拍清标记。

## 验收

1. 架子上一项，拖起再松在文件行：条数不变。
2. 从 Finder 再拖同一原件：仍可进第二条。
3. 结果卡拖到文件行：仍可进材料。
4. `swift run DropAgentCheck` 与 `--e2e` 通过。

## 验证

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```
