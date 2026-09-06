# 分包边界整理：App 不再当第二套 Capture

## 背景目标

对照 `03` 分包与四条调用链，把已经越界的编排收回内核，删掉死别名和重复进货入口。不新开 Utils 包，不拆测试大文件，不改四条链的用户行为。

## 当前行为与问题证据

包箭头大体正确。实问题：

1. `03` 写 App 不依赖 Capture，`Package.swift` 和 `AppSession` / `AppDelegate` / `CaptureLaunch` 直接读浏览器、AX、Automation、recovery。
2. `IsolatedTUIHome.copyLogin` 在 App 发送后再调一次；PTY 失败时 App 自己 `Shelf.patch` 把 `.sent` 打回 `.idle`。
3. `IncomingDrop.admit` 与 `Ingest.admitClipboard` 两套读板；`pickCodex` / `openCodexInstall` 无调用方。

Hash / 去符号链接在 Ingest、Job、TUI 各有一份小实现。禁止 Utils 包，第一版保留，不合并。

## 范围

- Capture 冻结、门禁、失败文案经 `Ingest.PageAdmit` 暴露；App 只调 Ingest。
- `IngestService` 自带系统 Capture 适配器；Check 仍可注入桩。
- 拖入剪贴板走 `admitPasteboard`。
- TUI `prepare` 含 copyLogin；`revertSend` 收口发送失败。
- 删死别名。更新 `03` 与 ingest / app-shell / capture 细案。

## 非目标

- 不拆 `PanelRootView` / `Check/main.swift` / `AppE2E.swift`。
- 不合并 FileDigest / stripSymlinks（会逼出 Utils 包）。
- 不改 Recipe 宫格、不改抓页用户文案、不碰用户主 Chrome。
- Developer ID。

## 使用场景

人在 Safari 按 ⌃⌥W：仍先记下前台浏览器，再开面板去抓。失败文案、去授权、再试不变。拖到列表 / 粘贴仍部分成功。发给 TUI 仍复制登录态、失败仍把条目打回待处理。

## 方案与关键决策

1. `CaptureLaunch` 迁入 Capture 包。`PageAdmit.freezeFrontBrowser` / `snapshot` / `decide` / `failure` 是 App 唯一抓页门面。
2. `PageAdmitToken.none` 给 e2e「没有前台浏览器」；`.snapshot()` 给热键。`--capture` 仍在 `main` 里 freeze。
3. App 的 SPM 依赖去掉 Capture。AppE2E 用 Safari bundle id 判断最前，不再 `BrowserFront.current()`。
4. `--capture` 诊断只打印 WEB 条或错误，不再自己探 AX。

## 输入输出与依赖

输入：现有四条链。输出：App 无 `import DropAgentCapture`。依赖现有 Check / e2e 契约（失败文案、Safari WEB 条）。

## 文件 / 模块边界

- `macos/Packages/DropAgentCapture/Sources/CaptureLaunch.swift`（从 App 迁入）
- `macos/Packages/DropAgentIngest/Sources/PageAdmit.swift`
- `macos/Packages/DropAgentIngest/Sources/IngestService.swift`
- `macos/Packages/DropAgentTUI/Sources/IsolatedTUIHome.swift`、`TUIService.swift`
- `macos/App/AppSession.swift`、`AppDelegate.swift`、`DropAgentMain.swift`、`AppE2E.swift`、`PlatformAdapters.swift`
- `macos/Package.swift`
- `03-tech-architecture.md`、`design/modules/{ingest,app-shell,capture}.md`
- 本 spec

## 验收标准

1. `macos/App` 无 `import DropAgentCapture`；`Package.swift` 的 DropAgent target 不依赖 Capture。
2. 抓页仍：热键 freeze → `admitCurrentPage`；无前台浏览器不造 WEB 条；文案仍含「没读到当前页」/ 辅助功能。
3. Check：`PageAdmit.decide(.none)` 不 proceed；`admitCurrentPage` 桩失败仍是 `captureFailed`、架子空。
4. Check：TUI send 后隔离 home 有登录文件复制（prepare 内完成）；`revertSend` 把 `.sent` 打回 `.idle`。
5. Check 全绿。`--capture` 诊断行含 WEB 或错误，不再探主 Chrome。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
```

## 假设与开放问题

`--capture` 输出不再带 `ax=` / `auto=`。IsolationShown.spokenFact 与 Agent.isolationCopy 入参不同，不合并。
