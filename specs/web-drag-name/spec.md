# 网站拖出文件夹用标题命名

## 背景目标

`02` §6、`03` §9.8：网站条拖到 Finder 落下文件夹，里面是链接、正文、截图。内核已经交出整个抓页目录。目录名却是 Inbox 里的条目 UUID，桌面上是一串看不懂的 id，不像「Example Domain」。

## 当前行为与问题证据

`PasteboardService.representation(forStaged:)` 对 `.web` 把 `parts.first.url.deletingLastPathComponent()` 放进 `fileURLs`。抓页写入 `Inbox/<id>/url.txt`，父目录就是 UUID。Check `pasteboardWebFolderLands` 用手工文件夹名 `site`，没覆盖真实抓页这条路径。`--e2e` 抓到 WEB 后删条，没有落到桌面。

## 范围

- 未跑完的 WEB 拖出 / 复制：对方拿到的文件夹名用条目标题（去掉 `/` `:` 等非法字符），不是 Inbox UUID。
- Inbox 仍按 id 存；不改原网页、不用符号链接。
- `--e2e`：Safari 抓 example.com 后拖出，桌面文件夹名是页标题，内有 `url.txt` / `page.md` / `snapshot.png`。
- 不改 DIR 条（已经按原文件夹名交）。

## 非目标

- Developer ID。
- 不改抓页写入 Inbox 的布局。
- 不把 UUID 条目目录改名。

## 使用场景

抓一页，从架子拖到桌面：出现「Example Domain」文件夹，打开能看到链接、正文、截图。

## 方案与关键决策

拖出时把 Inbox 目录复制到临时目录下以标题命名的文件夹，再把这份复制交给剪贴板。标题为空或非法时用「网站」。

## 输入输出与依赖

输入：WEB Item（title + parts）。输出：`fileURLs` 指向标题命名的目录副本。依赖现有 `itemProvider` / `land`。

## 文件 / 模块边界

- `macos/Packages/DropAgentPasteboard/Sources/PasteboardService.swift`
- `macos/Check/main.swift`
- `macos/App/AppE2E.swift`
- 本 spec

## 验收标准

1. Check：WEB 条 `fileURLs` 第一条的最后一段是条目标题；该目录里有 `page.md`；Inbox 原目录名不变。
2. `--e2e`：example.com 抓页后落到桌面的是目录，名字含 Example，内有 `url.txt` / `page.md` / `snapshot.png`。
3. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

Finder 若再给目录加「 的副本」是系统行为。标题过长截断，不另做唯一序号（临时路径已按条目 id 隔离）。
