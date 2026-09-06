# 文件夹拖出要落下目录，不是一个空文件名

## 背景目标

`01` 接收文件夹，还没跑的原件也能拖走。架子上的 DIR 条交出去时，对方应拿到那个目录。

## 当前行为与问题证据

`PasteboardService.contentType` 用 `URL.hasDirectoryPath`。进货副本路径是 `Inbox/<id>/bundle`，没有尾斜杠，被当成普通文件味道。

## 范围

- 拖出 / 复制 DIR：`fileURLs` 指向 Inbox 里那份目录副本。
- `NSItemProvider` 按文件系统判断目录，注册 folder，不看路径写没写 `/`。
- 落到桌面后能看见里面的文件；原文件夹不动。
- 不改 WEB 那组材料的拖出（仍交整个抓页文件夹）。

## 非目标

- Developer ID、顶边真人拖。
- 不做文件夹阅读器。

## 使用场景

人拖进一个材料夹，先不跑，再从架子拖到桌面：落下的是文件夹，打开能看到原来那些文件。

## 方案与关键决策

`contentType` 先 `FileManager` 问是不是目录，再退回扩展名。

## 输入输出与依赖

输入：`Item.kind == .folder` 的 parts。输出：Pasteboard 文件 URL。依赖现有 `itemProvider` / `representation`。

## 文件 / 模块边界

- `macos/Packages/DropAgentPasteboard/Sources/PasteboardService.swift`
- `macos/Check/main.swift`
- `macos/App/AppE2E.swift`：顶边条宽度（`EdgePlacement`，同一试用缺口）

## 验收标准

1. Check：DIR 条的 `fileURLs` 是目录；拖出落到桌面后目录里有原来的文件名。
2. Check：原文件夹内容不变。
3. `--e2e`：当前屏顶边命中框宽度是可见区域宽 − 16，不是固定 280pt；屏幕中间不命中。
4. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

顶边真人从 Finder 拖文件仍要亲手走一次。
