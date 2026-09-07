# 端到端边界整理：调用链分文件，去掉 huge class

## 背景与目标

对照 `03-tech-architecture.md` 的分包和四条调用链，把已经对上包箭头、但文件里职责混在一起的代码切开。用户行为不变。完成等级：代码结构内部完整，产品行为仍是现有等级。

## 当前行为与问题证据

包依赖已经符合 `03`：App 不 import Capture；Ingest → Shelf + Capture；Job / TUI → Shelf + Agent。

实问题是类型和文件过大、一条文件里叠了多条链：

| 位置 | 行数 | 混了什么 |
|------|------|----------|
| `PanelRootView` | 2087 | 头、架子、动作、结果、Markdown、按钮、行 |
| `AppSession` | 1242 | A 进货 / B Recipe / C TUI / D 拿走 / 授权 / 设置 |
| `AppDelegate` | 963 | 生命周期、面板、菜单栏、顶边投放、图标绘制 |
| `AgentService.swift` | 512 | 探测服务 + CodexCLI + JSONL |
| `AgentEngine.swift` | 426 | 引擎枚举 + Presence + Settings + Run 协议 |
| `IngestService.swift` | 417 | admit API + 抓页回填 + Hash + 去符号链接 |
| `JobService.swift` | 376 | 任务编排 + JobControl + FileDigest |
| `HotKeyCenter.swift` | 378 | 和弦、文案、注册器 |

`Check/main.swift` 和 `AppE2E.swift` 是测试跑法，不拆。FileDigest / stripSymlinks 在 Ingest、Job、TUI 各留一份，不合并成 Utils。

## 范围

- 内核：按类型切开，public API 签名不变。
- AppSession 仍是唯一 ObservableObject 装配点；方法按调用链放到 extension 文件。
- AppDelegate 抽出顶边投放控制器、菜单栏拖入视图、面板尺寸常量。
- PanelRootView 变成拼装；头、架子、动作区、结果、composer、行、按钮各自成 View。
- 更新 `design/modules/app-shell.md`、`ai-pane.md` 的代码位置。

## 非目标

- 不改四条链的用户行为、文案、快捷键、抓页门禁。
- 不新建 Utils / Common / Helper 包。
- 不合并 FileDigest / stripSymlinks。
- 不拆 Check / AppE2E / PanelPreview。
- 不把 Shelf 塞进 View。
- 不改 Recipe、不碰用户主 Chrome。

## 使用场景

拖入列表、拖到 AI 区、粘贴、抓页、加入选中文件、确认 Recipe、发送 TUI、拖出/复制：入口、顺序、失败文案与现在相同。

## 方案与关键决策

1. AppSession 继续当装配点。Views 只跟它说话。拆的是文件和子 View，不是第二套状态源。
2. 四条链文件：`AppSession+Admit` / `+Job` / `+TUI` / `+Export`。授权和设置不是第五条链，单独 `+Setup` / `+Settings`。
3. `EdgeDropController` 接手顶边投放；AppDelegate 只装配窗口、快捷键、菜单栏。
4. `private` 只在本文件用的辅助函数上保留；跨 extension 的 `follow` / `human` 改为模块内可见。
5. CodexCLI、CodexJSONL、JobControl、PageTitle、MaterialCopy 各自成文件，仍留在原包。

## 输入输出与依赖

输入：现有四条链和 public API。输出：同行为、更小的类型文件。依赖现有 Check / e2e 契约。

## 文件 / 模块边界

内核：

- Agent：`AgentEngine` / `AgentPresence` / `AgentRun` / `AgentService` / `CodexCLI` / `CodexJSONL`
- Job：`JobTypes` / `JobService` / `JobControl` / `JobDigest`
- Ingest：`IngestTypes` / `IngestService` / `IngestCapture` / `WeblocURL` / `FileDigest` / `MaterialCopy`
- Capture：`CaptureTypes` / `CaptureService` / `PageTitle`
- TUI：`TUITypes` / `TUIService`

App：

- `AppSession.swift` + 链 extension
- `EdgeDropController.swift`、`EdgeDropView.swift`、`StatusDropView.swift`、`PanelChrome.swift`
- `PanelRootView.swift`（拼装）+ `PanelHeader` / `ShelfColumn` / `AIPane` / `WorkPane` / `ResultPane` / `ComposerBar` / `ItemRowView` / `PaperButtons`
- `HotKeyChord.swift` / `HotKeyCopy.swift` / `HotKeyCenter.swift`

## 验收标准

1. `macos/App` 无 `import DropAgentCapture`；包依赖方向与 `03` 一致。
2. AppSession 对外方法名不变；四条链分别在对应 extension 文件。
3. 生产代码里没有超过约 400 行的单一类型文件，除 AppSession 装配点按链拆文件后的合计。AppDelegate（生命周期）和 SettingsPane（设置页）可略超；Check / AppE2E / PanelPreview 不拆。
4. `PanelRootView` 只拼装，不再内嵌 Markdown / 行 / 按钮实现。
5. Check 全绿；`swift build --product DropAgent` 成功。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
```

## 假设与开放问题

AppSession 作为 ObservableObject 仍会有不少 `@Published` 和计算属性，这是装配点，不拆成多个 store。测试大文件保持原样。

---

## 第二轮（本轮）

第一轮之后生产代码还偏大或混职责：

| 位置 | 行数 | 问题 |
|------|------|------|
| `AppDelegate` | 513 | 生命周期、面板、菜单栏仍在一个文件 |
| `SettingsPane` | 437 | 七个设置区块 + 表单零件 |
| `IngestService` | 321 | admit 文件/剪贴板 和 抓页回填叠在一起 |
| `JobService` | 320 | 任务编排和磁盘副本/manifest 叠在一起 |
| `AppSession+Setup` | 354 | 抓页、选中文件、授权叠在一起 |
| `SystemCaptureAdapters` | 239 | 三个适配器一个文件 |
| `AccessibilityPage` | 336 | 读网页 URL 和读打开的本地文件叠在一起 |

### 第二轮范围

- `AppDelegate+Panel` / `+StatusItem`；主文件只留启动、热键、装配。
- 设置页拆成区块 View + 共用表单零件。
- `IngestCapture` 接手抓页 stub/回填；`JobWorkspace` 接手副本目录磁盘操作。
- `AppSession+Capture` / `+FrontFiles`；授权仍在 `+Setup`。
- Capture 适配器和 AX 读页/读文件分开。
- 各链 extension 只 import 自己需要的包。
- 仍不拆 Check / AppE2E / PanelPreview，不合并 FileDigest。

### 第二轮验收

1. 生产源文件（不含 Check / AppE2E / PanelPreview）都不超过约 350 行。
2. `IngestService` 不再包含 `fillDroppedPage` / `writeCapturedPage`。
3. `JobService.start` 的复制/冻结/manifest 走 `JobWorkspace`。
4. Check 全绿；`swift build --product DropAgent` 成功。

---

## 第三轮（本轮）

第二轮之后行数已经压住，剩下的是错位类型、重复实现、无用依赖：

| 位置 | 问题 |
|------|------|
| `Package.swift` App target | 链了 `ScreenCaptureKit`，App 源码不用抓屏 |
| `CapturingBody.swift` | 抓页等待 UI 里塞了 `RecipeGlyph` / `RecipeFacts`；`runningEventColor` 没人调用 |
| `Palette.swift` | 颜色和 `PaperHostView` / `ClickModifiers` 叠在一起 |
| `OpenPanelHost.swift` | 文件面板和状态栏显隐叠在一起 |
| `PanelInspect.swift` | 预览提示、TTY 颜色、拖入遮罩叠在一起 |
| `ResultPane.swift` | 重复实现 `SourceLinkText` / `htmlURL`；还 import 了不用的 Job |
| `AppSession.swift` | 装配点里仍留着隐藏/删除/选择 |
| `AppDelegate.swift` | import 了不用的 Agent / Ingest |
| `JobService.swift` | import 了不用的 CryptoKit |

### 第三轮范围

- App target 不再链 ScreenCaptureKit；Check 锁住 App 不依赖 Capture。
- 类型归位：Recipe 图标/确认四行、纸面 Host、点击修饰、状态栏显隐、TTY 色、拖入遮罩。
- Result 预览抽到 `ResultPreview`；删掉重复的链接/HTML 判定。
- 架子上的选中/隐藏/删除放到 `AppSession+Shelf`。
- 删无用 import 和死代码。
- 仍不拆 Check / AppE2E / PanelPreview，不合并 FileDigest，不新建 Utils。

### 第三轮验收

1. App 源码和 App target 都不依赖 DropAgentCapture / ScreenCaptureKit。
2. `CapturingBody` 不再包含 Recipe 类型；`ResultPane` 不再复制 `SourceLinkText`。
3. 隐藏/删除/选择不在 `AppSession.swift` 主文件。
4. Check 全绿；`swift build --product DropAgent` 成功。
5. 用户行为不变。
