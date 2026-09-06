# 模块：Capture

包：`DropAgentCapture`

## 做什么

读前台浏览器的 URL 和标题；DropAgent **自己联网**拉 HTML，抽正文写成 `page.md`（链接按页 URL 补成绝对地址）；对可见窗口截图 `snapshot.png`。给 Ingest 用。

## 不做什么

不 `Shelf.add`。不承诺带上浏览器登录 Cookie。不装扩展。不把抓页说成 Agent Workspace。

## Public

```text
captureFrontBrowser() async throws -> PageCapture

struct PageCapture {
  url: URL
  title: String
  markdown: Data?      // 失败则为 nil
  snapshotPNG: Data?   // 失败则为 nil
  failures: [CaptureFailure]  // 给 UI 的人话原因
}
```

## 浏览器

| 目标 | 策略 |
|------|------|
| Safari | AppleScript / Accessibility：当前 tab URL、标题 |
| Chrome | 同上（常见脚本接口） |
| Edge | 尽量；失败进 failures |
| 其他 | 读不到：抛 `unsupportedBrowser`，Ingest 不造 WEB 条 |

## 降级（必须）

1. 有 URL+标题，md 或图失败：仍返回，`failures` 非空。Ingest 仍可 `add` 一条 WEB，缺的 part 不造假文件。  
2. URL 都没有：整次失败，架子不变。  
3. 网络错误：链接还在，md 为 nil，failures 含「正文没拉下来」。

## 调用谁

系统 API + HTTP。禁止依赖 Shelf / Job / TUI。
