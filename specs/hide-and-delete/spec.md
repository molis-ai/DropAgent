# 列表：隐藏和删除

## 目标

输入区和结果区都提供两种动作。隐藏：只从列表拿掉。删除：清掉 DropAgent 里的文件，并从列表拿掉。原件不动。

## 行为

- **隐藏**：现有移除。Inbox / Jobs 里的文件还在。
- **删除（输入）**：删掉 Inbox 里这条的副本目录，不删 `sourceURL` 原件。运行中不可删、不可隐藏。
- **删除（结果）**：删掉 Jobs 里这份产出所在任务目录（仅限 Jobs 根之下）。
- 删除路径必须在 Inbox 或 Jobs 根目录内，否则不动。
- ⌫ 仍是隐藏，不是删除。

## UI

两列每行：叉 = 隐藏；垃圾桶 = 删除。右键菜单同样两项。删除用 destructive。

## 验收

1. Check：admit 一份 PDF 后删除，Inbox 副本没了，原件还在，架子上没这条。
2. Check：Job 产出删除后 output 文件没了，结果列表没这条。
3. Check：删除不会去掉 Inbox 之外的 sourceURL。
4. `swift run DropAgentCheck`；`swift build --product DropAgent`。
