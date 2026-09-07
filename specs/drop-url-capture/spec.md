# 拖进 / 粘贴网址：自动抓成网站条

## 背景目标

把 http(s) 放到架子上（顶边、菜单栏图标、左列表、粘贴）应得到和 ⌃⌥W 同类的网站材料：链接、正文、截图。现在只进一条 URL，人还要再按一次抓页。

## 当前行为与问题证据

- `Ingest.admit` 对 http(s) / webloc / 整段网址文本写 `kind == .url`、`link.txt`，不调用 Capture。
- ⌃⌥W 走 `captureFrontBrowser`：读前台浏览器 + 拉 HTML + 先截前台窗。面板抢前台后，窗截图会变成 DropAgent。
- 拖到右侧 AI 区也会 `admit`，随后 `TUI.send`。若默认抓页，链接进会话会被改成一次联网抓取。

## 范围

- 架子进货口（图标 / 顶边 / 左列表 / ⌘V / `admit(urls:)` 默认）对 http(s) 与可读 webloc：立刻加一条 `WEB`（`url.txt`，event「正在抓取」，`status` 仍是 idle），后台 `captureURL` 补 `page.md` / `snapshot.png` 和标题。
- `captureURL`：只按该 URL 拉 HTML + 隐藏 WKWebView 截图。不读前台浏览器，不截前台窗。
- 右侧 AI 区 `admitToTUI`：`capturePages: false`，仍是 URL 条，把链接送进终端。
- 失败：条还在，保留 `url.txt`，event 用现有 Capture 失败文案（如「正文没拉下来」）。不造假 md/png。
- 不要把 `isCapturing` / 全屏「正在抓当前页」用在这条路上。
- 设置「浏览器」、`01` / `02` / ingest / capture / 原型与产品事实对齐。

## 非目标

- 不装扩展、不带浏览器 Cookie。登录墙与 ⌃⌥W 正文同一限制。
- Safari 标签拖成窗口管理、剪贴板没有 URL：仍进不了货，不偷偷抓前台页。
- 不改 Recipe / TUI 发送协议。
- 不把 stub 标成 `running`（会锁删除）。

## 使用场景

1. Chrome 标签拖到顶边：架子马上出现网站条，随后补正文和截图。
2. ⌘V 一段 `https://…`：同上。
3. 把链接拖到右侧 AI：仍是链接，发给当前终端，不抓页。
4. 正文拉失败：条还在，能打开链接；副标题写失败原因。

## 方案与关键决策

- 有 URL 就不必走 `captureFrontBrowser`。热键仍先读前台再 `fillPage`（窗截图优先）；拖入/粘贴只 `fillPage`（无窗 pid）。
- 先 `Shelf.add` 再异步填充，避免人等网络。
- App 仍不 import Capture；填充走 `Ingest.captureDroppedPages`。

## 输入输出与依赖

输入：http(s) URL、webloc、整段网址文本。  
输出：WEB Item；`AdmitResult.pageCaptureIDs`。  
依赖：现有 `PageFetching` / `URLPageSnapshot` / `Shelf.patch`。

## 文件 / 模块边界

- `macos/Packages/DropAgentCapture/Sources/PageCapture.swift`
- `macos/Packages/DropAgentIngest/Sources/IngestService.swift`
- `macos/Packages/DropAgentIngest/Sources/DropProviders.swift`
- `macos/App/AppSession.swift`
- `macos/App/SettingsPane.swift`
- `macos/Check/main.swift`
- `macos/App/AppE2E.swift`
- `01-requirements.md` / `02-prototype-design.md` / `design/modules/ingest.md` / `design/modules/capture.md` / `03-tech-architecture.md` / `prototype/index.html`
- 本 spec

## 验收标准

1. Check：`admit(https)` 立刻 `.web`、`url.txt`、event「正在抓取」、`pageCaptureIDs` 非空；`capturePages: false` 仍是 `.url` / `link.txt`。
2. Check：FailFetch 填充后仍是 WEB，event 含「正文没拉下来」，无 `page.md`。
3. Check：Stub HTML + 页截图填充后有 `page.md` / `snapshot.png`，标题来自 HTML；`captureURL` 不调用前台窗截图。
4. Check：webloc / 剪贴板整段 https / `WebURLsWithTitlesPboardType` 默认进 WEB stub。
5. `--e2e`：粘贴 https 后 kind 是 WEB，复制交出文件夹（不是空 `fileURLs` 的 URL 条）。
6. Check 全绿。App 不 import Capture。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
```

## 假设与开放问题

- 粘贴整段网址与拖进架子同一条动线（已确认）。
- 多条 URL 一次进货时按顺序填充，不并行打爆网络。
