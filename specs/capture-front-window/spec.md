# 抓页先读前台窗和网页区域；WEB 文本带换行

## 背景目标

`01` §12 保证 Safari、Chrome。Safari 已能在 `--e2e` 里抓到 Example Domain。Chrome 的 AX 树大且慢：现在对每个节点设 0.2s 超时再广度优先 80 步，1.2s 预算很容易耗尽，随后才落到 AppleScript。多窗口时 `kAXWindows` 也不保证前台窗在前，可能读到后台页。

拖出的网站文件夹里，`url.txt` 没有尾换行；预览 fixture 有。打开或丢给别的工具会看到「文件末尾没有换行」。

## 当前行为与问题证据

- `AccessibilityPage.read`：按 `kAXWindows` 排序（标准窗优先），不先读 `AXFocusedWindow` / `AXMainWindow`。
- `readWindow` 在窗级属性失败后走 `toolbarURL` 再 `firstURL`（最多 80 个节点）。Chrome 的地址通常在 `AXWebArea` 的 `AXURL`。
- `IngestService.admitCurrentPage`：`Data(captured.url.absoluteString.utf8)` 写入 `url.txt`，无 `\n`。`page.md` 直接写 Capture 的 Data。
- `PanelPreview` 写的是 `"https://example.com\n"`。

## 范围

- 读前台浏览器：先 focused 窗，再 main 窗，再其余窗；同一窗不重复读。
- 窗级 `AXDocument` / `AXURL` 之后，先定向找 `AXWebArea` 的 URL，再 toolbar / 有限 BFS。子节点按角色排序：`AXWebArea` 先于工具栏和普通 Group。
- BFS 上限降到 24。1.2s 总预算不变。
- `url.txt`、`page.md` 写成 UTF-8 文本且以换行结尾。空正文仍不造假文件。
- Check 锁住角色排序、文本换行、原有 example.com Markdown。
- 不激活、不 AX 读用户正在用的主 Chrome 窗。Chrome 真窗仍标未现场验证。

## 非目标

- 不改四条调用链。
- 不把抓页 e2e 改成 skip。
- 不 `tell application "Google Chrome"` 去碰用户主配置。
- Developer ID。

## 使用场景

Chrome 在最前、旁边还有别的 Chrome 窗时，⌃⌥W 抓的是眼前这一页。拖出的文件夹里 `url.txt` 是一行完整地址。

## 方案与关键决策

AX 仍是第一路，AppleScript 3s 超时仍是退路。不新开 CDP、不装扩展。文本换行只发生在 Ingest 落盘，不改 HTML 转换语义。

## 输入输出与依赖

输入：前台浏览器 pid、抓到的 URL/HTML。输出：同一套 `PageCapture`；Inbox 里 `url.txt` / `page.md` 以 `\n` 结尾。

## 文件 / 模块边界

- `macos/Packages/DropAgentCapture/Sources/AccessibilityPage.swift`
- `macos/Packages/DropAgentIngest/Sources/IngestService.swift`
- `macos/Check/main.swift`
- `design/modules/capture.md`
- 本 spec

## 验收标准

1. Check：`roleRank("AXWebArea")` 高于 `AXGroup` / `AXButton`；`childVisitOrder` 把 WebArea 排到前面。
2. Check：liveWebAdmit 的 `url.txt` 正文是 `https://example.com/` 且以换行结尾；`page.md` 非空且以换行结尾。
3. Check：原有 AX 自进程不挂、example.com Markdown、Safari 标题回退仍过。
4. 不把 Chrome 标成已现场验证。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
```

## 假设与开放问题

用户主 Chrome 窗口禁止激活、禁止 AX。本切片用 Check 锁住策略；Chrome 真窗要等一骏自己把 Chrome 放到最前再抓。
