# 模块：Capture

包：`DropAgentCapture`

## 做什么

读前台浏览器的 URL 和标题，或按已有 URL 取页；DropAgent **自己联网**拉 HTML，抽正文写成 `page.md`（链接按页 URL 补成绝对地址）；热键路径对可见窗口截图 `snapshot.png`，拖入/粘贴路径只用隐藏页截图。给 Ingest 用。

## 不做什么

不 `Shelf.add`。不承诺带上浏览器登录 Cookie。不装扩展。不把抓页说成 Agent Workspace。

## Public

```text
captureFrontBrowser() async throws -> PageCapture
captureURL(_ url:title:) async -> PageCapture
CaptureLaunch.freeze()   // --capture 在进程启动时钉死前台；Ingest.PageAdmit 包装给 App
AutomationAccess.probe / isAllowed / requestIfNeeded(bundleIdentifier)
CapturePermissions.status / liveStatus
FrontFiles.classify / decide / resolve / collect / paths

struct PageCapture {
  url: URL
  title: String
  markdown: Data?      // 失败则为 nil
  snapshotPNG: Data?   // 失败则为 nil
  failures: [CaptureFailure]  // 给 UI 的人话原因
}
```

`requestIfNeeded` 先打正在跑的 regular 应用真实 bundle / pid，再 `AEDeterminePermissionToAutomateTarget(..., true)`。仍未允许则同进程发一条只读 Apple Event。禁止用 `osascript` 触发自动化对话框。探测用 `ask=false`。未允许时抓页不跑 AppleScript。

## 浏览器

| 目标 | 策略 |
|------|------|
| Safari | Accessibility 先读 focused/main 窗的 `AXDocument`；失败再 AppleScript |
| Chrome | 同上，窗级属性之后先找 `AXWebArea` 的 URL，再 toolbar；同一 `com.google.chrome` 只有一个进程时，AppleScript 3s 超时是退路。多实例时只读该 pid 的 AX，不 `tell application "Google Chrome"` |
| Edge | 尽量；失败进 failures |
| 其他 | 读不到：抛 `unsupportedBrowser`，Ingest 不造 WEB 条 |

## 降级（必须）

1. 有 URL+标题，md 或图失败：仍返回，`failures` 非空。Ingest 仍可 `add` 一条 WEB，缺的 part 不造假文件。  
2. 热键路径 URL 都没有：整次失败，架子不变。拖入/粘贴已有 URL：先造 stub，失败只改 event。  
3. 网络错误：链接还在，md 为 nil，failures 含「正文没拉下来」。
4. `captureURL` 不截前台窗，只拉 HTML + `PageSnapshotting`。

## 调用谁

系统 API + HTTP。禁止依赖 Shelf / Job / TUI。
