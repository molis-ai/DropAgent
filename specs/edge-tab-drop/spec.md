# 顶边条：鼠标在区内就要高亮，网页标签松手能进货

## 背景目标

屏幕顶边投放条是进货口。人把网页标签拖上去，条子出现了，但不变色、松手也没有条目。

## 当前行为与问题证据

- 亮条条件是鼠标进入「可见区域顶往下 28pt 到屏幕顶」，这条带包含菜单栏。
- 投放窗口却贴在菜单栏**下面**，高 36pt；命中带比窗口还矮 8pt。鼠标在菜单栏里时，人看见条子，光标并不在 `EdgeDropView` 上。
- 高亮只写在 `draggingEntered`。光标不在视图上、或剪贴板 UTI 没登记，就不会变黑。
- 松手若落在菜单栏：全局监视立刻 `hideEdge()`，AppKit drop 还没到就被收掉。
- 松手若落在条子上：鼠标抬起是本 App 的本地事件，现有监视只听全局，等不到 `mouseUp`；只能赌 `performDragOperation`。
- Chrome / Safari 标签常见 `WebURLsWithTitlesPboardType`、`public.url`，外加还没落地的 `.webloc` 承诺文件。`ClipboardPayload.from` 先读文件 URL，文件不存在 → 进货失败或空。

Safari 把标签拖成窗口管理、剪贴板里根本没有 URL 时，系统交不出链接。那种情况高亮仍要有；进货仍走地址栏链接、Chrome/Edge 标签，或 ⌃⌥W 抓页。不在松手时偷偷抓前台页。

真人复验：Chrome 标签拖到已出现的条子上松手，仍没有条目。Chrome 的网址是 promised（系统把我们当成投放目的地来问才给）。条子却是鼠标已经到顶之后才出现，窗口垫在光标底下，AppKit 不发 drop；松手再读板，承诺还没兑现，是空的。

## 范围

- 顶边窗口盖住「纸条约高 + 菜单栏」：菜单栏那一段透明接拖，纸带画在可见区域顶下。
- 纸带高度 **48pt**（原 36）。命中带与窗口一致，不再用 28pt。
- 系统拖一开始（鼠标还在 Chrome 里）：顶边先放一层几乎看不见的接盘，等鼠标走进去，系统才会把这次拖交给我们。纸带仍是到顶才显示、并进入命中态。
- 拖的过程中若已经读到 http(s)，先记下；松手板空了就用这份。仍空则留 0.6s 等 AppKit 向 Chrome 要承诺数据。
- 鼠标在命中带内：纸带就是命中态。开着的面板若和顶边带重叠，仍亮顶边条。
- 登记浏览器拖常用 UTI（含 `WebURLsWithTitlesPboardType`、`public.item`、承诺文件、Chromium dummy / bookmark）。
- 剪贴板先取 http(s)（含 `public.url` 的 data、Chromium bookmark 字典）；不存在的文件 URL 丢掉。
- 同一次拖不进两次。
- 原型顶边条 48px；`--e2e` 核对几何。
- 不改四条调用链：顶边仍只 `Ingest.admit`。

## 非目标

- Developer ID。
- 不解析 TUI、不模拟键盘点浏览器。
- 不把标签拖放在本 spec 里做成抓页；进货之后的自动抓正文见 `drop-url-capture`。
- 不把顶边条改成整段拖都显示（仍是到顶才出现）。

## 使用场景

1. 从 Chrome 拖一个标签到屏幕最顶（含菜单栏）：条子变黑，松手后架子多一条网站（先链接，再补正文）。
2. 从 Finder 拖 PDF 到顶边：仍进架子、开面板。
3. Safari 标签若剪贴板没有 URL：条子仍变黑，松手不进假条目。

## 方案与关键决策

拖一开始就把接盘窗口放到顶上（透明），让鼠标是「走进去」而不是「窗口突然垫在光标下」。纸带到顶才显示。Chrome 的承诺数据走 `performDragOperation`；拖过程中已经能读到的链接先记下当备份。

## 输入输出与依赖

输入：全局/本地拖拽事件、拖拽剪贴板、`NSScreen` 几何。  
输出：顶边窗口 frame、命中态、`admitPasteboard` + 开面板。  
依赖：现有 `EdgeDropView`、`IncomingDrop`、`ClipboardPayload.from`。

## 文件 / 模块边界

- `macos/Packages/DropAgentIngest/Sources/PasteboardClipboard.swift`
- `macos/App/AppDelegate.swift`（`EdgePlacement` / `EdgeDropView` / 拖拽监视）
- `macos/App/PlatformAdapters.swift`
- `macos/App/AppE2E.swift`
- `macos/Check/main.swift`
- `prototype/index.html`
- 本 spec

## 验收标准

1. `EdgePlacement.frame`：纸带 48pt，窗口高度 = 48 + 菜单栏；鼠标在菜单栏里命中；屏幕中间和纸带下方不命中。`--e2e` 用当前 `NSScreen` 核对。
2. Check：只有 `WebURLsWithTitlesPboardType` 的 https → `.text` 且 kind 是 URL；不存在的 webloc 路径 + https → 用 https，不当文件；只有不存在的文件路径 → `.empty`。
3. 图标和顶边 `draggedTypes` 含 `WebURLsWithTitlesPboardType` 与 `public.item`。
4. 原型顶边条高度 48px，且已有 `.edge.hot`。
5. Check 全绿；四条调用链不变。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/dist/DropAgent.app/Contents/MacOS/DropAgent --e2e
```

顶边真人拖（Finder PDF、Chrome 标签）仍要亲手走一次。Safari 标签无 URL 时允许不进货。

## 假设与开放问题

菜单栏在本机普通权限下可被 statusBar 级窗口盖住接拖；若某系统版本不允许，菜单栏图标仍是进货口。
