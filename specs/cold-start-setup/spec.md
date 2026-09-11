# 冷启就绪卡：探测、要权、设置里复查

完成等级：4 内部完整（真机权限、首次打开、设置复查、抓页失败兜底可内部试用）。不是可发布（不签 Developer ID、不做安装器引导）。

## 背景与目标

抓页要辅助功能，Chrome / Safari 读不到地址时还要自动化（Apple Events）。macOS 的「自动化」列表是**请求驱动**的：App 必须先向目标应用发控制请求，才会出现并带上开关。人没法在空列表里手动加 DropAgent。

现在「去授权」在辅助功能已开时只打开自动化设置页，从不真正要权。探测用 `AEDeterminePermissionToAutomateTarget(..., false)`，抓页在未授权时故意不跑 `osascript`（避免卡在系统对话框上）。结果：设置页里没有 DropAgent，人以为装坏了。

终端是否装好、快捷键是否被占用，也只散落在页脚、芯片菜单和空态文案里。第一次打开面板时看不出能不能用。

要做的是方案 2：第一次打开面板时给一张**可跳过的就绪卡**，同一张清单常驻设置。已就绪的只打勾、不弹窗；缺的才动手。不是线性安装向导。

## 当前行为与问题证据

- 第一次打开：写 `opened` 标记并展开面板（`specs/first-open/spec.md`）。明确不做多页新手引导。本项加的是叠在面板上的一张卡，不是新窗口、不是多步 wizard。
- 设置页只有工作区 / 颜色 / 语言。
- 抓页失败「辅助功能已开，还要允许控制 Google Chrome」→「去授权」打开 `Privacy_Automation`。未发过 Apple Event 时列表里没有 DropAgent。
- `AutomationAccess.isAllowed` 静默探测；`AppleScriptBrowser` 未允许则不跑脚本。
- 快捷键占用只写在页脚。无 TUI 时发送禁用、进货仍可。
- 产品第一眼是架子。拖文件进货不需要任何上述权限。

## 范围

- 就绪卡 + 设置「使用准备」共用同一份快照。
- 清单：终端 Agent、⌃⌥D、⌃⌥W、辅助功能、本机已装且会走 AppleScript 的浏览器（Safari / Chrome / Edge / Brave）。
- 点浏览器授权：进程内 `AEDeterminePermissionToAutomateTarget(..., true)`。目标没在跑则先打开再要权。不经 `osascript` 触发对话框。
- 点「去授权」（抓页失败条）：辅助功能未开 → 要 AX；已开 → 对当前目标浏览器要自动化。不要只打开空的自动化页。要权后仍拒绝，再打开自动化页作退路（此时列表里应已有 DropAgent）。
- 已允许的权限不重复弹窗。`setupCardDismissed` 为真后不再自动弹出就绪卡；权限被收回或 CLI 卸了只反映在清单和齿轮标记上，用到缺的能力时走原来的失败条。
- 没装终端：写明可以先当置物架，并保留「如何安装」。不挡进货，不把无 CLI 当成装坏。
- 菜单栏图标 / 顶边投放在卡开着时仍走链 A 进货。面板内拖放被卡挡住，与设置页一致。
- 原型补同一张卡和设置里同一段清单，不发明内核没有的规则。

## 非目标

- 多页向导、强制走完才能用、示例 PDF、教练标记。
- 改快捷键组合、重映射被占用的键。
- 屏幕录制授权（截图失败仍按 Capture 降级：链接留下）。
- 启动时只根据前台 App 钉死一家浏览器。
- 把工作区路径 / 颜色 / 语言塞进冷启。
- App import Capture。四条调用链不变。不经 `osascript` 要权。
- Developer ID / 安装包里的独立 Setup.app。
- `specs/extra-runtimes` 的新引擎名单：清单用现有 `installedEngines()`，不在本项发明第五家探测规则。

## 使用场景

1. 第一次双击 DropAgent：面板出来，空架子可见。动作区第一拍「这是一个架子。」本机有 Chrome 没开、辅助功能未开、装了 Grok。下一步到抓页授权。人先点「允许」开辅助功能，再点 Chrome「打开并允许」，系统弹出「DropAgent 想要控制 Google Chrome」。允许后 Chrome 行打点。点「跳过」进空架子，仍可拖文件。
2. 本机权限和 Safari 控制都已有、没装任何 CLI：卡仍出现，终端行写「未发现终端 Agent。可以先把文件放在架子上。」人点「以后再说」，齿轮留墨点；设置里同一行可点如何安装。
3. 人点了以后再说，后来在 Chrome 里 ⌃⌥W：若自动化仍未给，失败条「去授权」弹出控制 Chrome 的系统框，而不是一个没有 DropAgent 的设置页。
4. 人在设置里关掉辅助功能：就绪卡不自动再蹦出来；齿轮有墨点；抓页失败条仍能要权。
5. `--e2e` / `--preview` / `--capture` 不自动出卡、不写 `setupCardDismissed`。预览有单独场景拍卡和设置清单。

## 方案与关键决策

### 形态

一张清单，两处渲染：

| 表面 | 何时 | 出口 |
|------|------|------|
| 就绪卡 | 人点「去准备」，且未 dismiss，且抓页权限未齐 | 「以后再说」或抓页权限变齐后自动收起 |
| 设置「使用准备」 | 齿轮打开，永远在工作区之上 | 无独立出口；「完成」关设置 |

不是新窗口。卡盖住左列表 / 右 AI（终端仍留在视图树，避免拆 PTY），头上芯片 / 齿轮 / 最小化 / 关闭仍可用。点齿轮视为暂时去设置，**不是** dismiss；关设置后若仍未 dismiss 且未齐，卡回来。

### 何时出卡、何时不再出

```text
shouldShowCard = !isDiagnostic && panelVisible && !setupCardDismissed && !captureReady && requested
```

`requested` 是本次进程的显式请求（空态「去准备」、预览 / e2e），不写盘。第一次打开不再自动出卡；抓页授权在引导的第二拍。详见 `specs/onboarding-flow/spec.md`。

`captureReady`：辅助功能已信任，**且**至少一家已装 AppleScript 浏览器 `allowed == true`（没有浏览器行则只看辅助功能）。

不把「有终端」和「快捷键可用」算进 `captureReady`。没有 CLI 仍可当置物架；键被占用只能说明，第一版改不了。

- 「以后再说」：写 `prefs.setupCardDismissed = true`，收卡。
- 清单在卡还开着时变成 `captureReady`：同样写 dismiss 并收卡，不庆祝、不 toast。
- 关面板 / 最小化：不写 dismiss。下次打开面板，若仍未 dismiss 且未齐，卡还在。
- 之后新进程：`opened` 仍管是否自动弹出面板（first-open 不变）。卡只跟 `setupCardDismissed` + `captureReady` 走。
- 诊断启动：`shouldShowCard` 永假。

齿轮墨点（设置未打开时）：

```text
gearNeedsAttention = !hasAgent || !accessibilityTrusted || 任一已装 AppleScript 浏览器未允许
```

快捷键占用不加墨点，只出现在清单里。

### 清单行

顺序固定。浏览器行：本机没装则整行不出现。Arc / Firefox 不出现（不走 AppleScript，要权也没用）。

| 行 | 绿 | 未完成时的动作 |
|----|----|----------------|
| 终端 Agent | `installedEngines` 非空，展示当前芯片短名（auto 则当前探测到的） | 无 CLI：「可以先把文件放在架子上。」按钮「如何安装」走现有 `openTUIInstall`。有 CLI 不弹窗。 |
| 打开面板 ⌃⌥D | `hotKeyToggleOK` | 「被占用，点菜单栏图标打开。」无按钮。 |
| 抓当前页 ⌃⌥W | `hotKeyCaptureOK` | 「被占用，用菜单抓页。」无按钮。 |
| 辅助功能 | 当前进程真能用辅助功能：`AXIsProcessTrusted` / `AXIsProcessTrustedWithOptions(prompt:false)` 为真，或对 system-wide 元素的一次只读 AX 调用返回 `success` / `noValue` | 「去授权」→ `PageAdmit.requestTrustIfNeeded()`（已信任则立即返回）。 |
| `{浏览器名}` | 对该 bundle 探测 `allowed` | 见下 |

浏览器 Kind 仅 `usesAppleScript == true`：Safari、Chrome、Edge、Brave。一行一个 Kind。

- `installed`：该 Kind 任一已知 bundle 能被 `NSWorkspace.urlForApplication(withBundleIdentifier:)` 找到。Safari 在 macOS 上视为已装。
- `running`：任一已知 bundle 有 `NSRunningApplication`。
- 要权目标 bundle：有在跑的，用 `NSRunningApplication.bundleIdentifier` 的**原样大小写**（本机 Google Chrome 是 `com.google.Chrome`，不是代码里曾写的 `com.google.chrome`）。只拿 `activationPolicy == .regular` 的那份，不要打到 `com.google.Chrome.helper`。没在跑才退回 `primaryBundleIdentifier`（Chrome 也是 `com.google.Chrome`）。
- 已在跑未允许：「去授权」直接 `requestAutomation`（`ask=true`）。**禁止**因为静默探测是 `denied` 就只打开自动化设置。Chrome 未出现在 DropAgent 名下时，打开设置加不进开关。
- 静默探测对未要过权的 Chrome 本机返回 `errAEEventNotPermitted`（`-1743`），Safari 已允许则是 `noErr`。清单不得因此写成「系统已拒绝」或把按钮换成「在自动化里打开」。正在跑的未允许行只显示「去授权」。
- `ask=true` 之后仍是 denied，再打开自动化页（这时列表里才可能有 Chrome 开关）。
- Canary / Beta 等映射到同一 Kind：不拆多行。要权打正在跑的那份 bundle。
- 辅助功能：不得在未授权时假装打勾。adhoc 签名时 `AXIsProcessTrusted` 常在系统开关已开之后仍返回假，所以还要做一次不弹窗的实际 AX 读取；两者任一为真才打勾。系统列表里开着的仍可能是另一份身份（`.build` 裸二进制 vs `dist/DropAgent.app`、adhoc 重签换 CDHash）。有其他 DropAgent 在跑且当前进程读不到 AX 时，行文案写清「列表里那份不是当前这份」；实际读取也失败，则完全退出当前这份再打开。探测在主线程做，不要被后台队列写成假。

### 要权怎么发（根因修复）

`AutomationAccess.requestIfNeeded(bundleIdentifier:) -> AutomationState`：

- 先解析正在跑的 regular 应用的真实 bundle ID，目标描述符优先 `typeKernelProcessID`（那个 pid），再退回 `typeApplicationBundleID`。
- 调用 `AEDeterminePermissionToAutomateTarget(target, typeWildCard, typeWildCard, true)`。
- 本机证据：只调 `ask=true` 仍可能不把 Google Chrome 写入自动化列表（DropAgent 下只有 Safari）。若目标在跑且仍未 `allowed`，同进程再发一条只读 Apple Event（`NSAppleScript` `tell application id "…" to get name`，或等价 `AESendMessage`）。**禁止** `/usr/bin/osascript`。TCC 必须记在 `local.dropagent` / DropAgent.app。
- 已 `allowed` 则立刻返回，不弹窗。
- 探测仍用 `false`。抓页路径继续：未允许不跑脚本。
- 系统框会挡住主线程：必须先把菜单栏面板 `orderOut`（降到普通层、不接收鼠标），**再在主线程** `ask=true` 和只读 ping。后台线程的 `ask=true` 对正在跑的 Chrome 会直接 `-1743` 且不落表。主线程只在面板藏起来之后才阻塞。`hideForPrompt` 里的 `NSApp.activate` 会触发 `applicationDidBecomeActive`，这一下**不得**把面板抬回来。要权结束且仍要打开系统设置时，先放开这次挡住，等人从设置回到前台再恢复面板。不要在探测路径上用 `true`。
- 就绪卡 / 设置「使用准备」可见时每秒复探一次，人从系统设置回来不用再点一次。

`openPrivacySettings` 改成：

1. 辅助功能未开 → `requestTrustIfNeeded`，并打开辅助功能设置页（现有深链，人还得在列表里打开开关）。
2. 已开且失败目标是 AppleScript 浏览器 → `requestAutomation`。返回后若仍未允许，再打开自动化设置页。
3. 不要在未要权之前打开空的自动化页。

### 持久化

`prefs.json`（`AppPreferences`）增加 `setupCardDismissed: Bool`，缺省 `false`。旧文件没有该键视为未 dismiss。

不把 AX / 自动化 / CLI / 热键结果写入磁盘。每次打开卡、打开设置、面板变为可见、从系统设置回到前台时现场探测。

`opened` 标记仍只表示「已经自动展开过面板」，与卡无关。

### 和 first-open / 设置页的关系

- first-open：照旧，诊断启动不弹面板、不写 `opened`。本项不改那份标记语义。
- first-open 非目标「不做多页新手引导」仍然成立：不是新窗口。动作区一次一拍，随时可跳过，架子始终可拖。
- 设置页在现有三块之上加「使用准备」，控件、字号、分段标题跟工作区块一致。

## 端到端方案（模块、数据、调用）

本项不是第五条链。就绪卡是 App 壳。要权经 Ingest.PageAdmit 进 Capture。用到抓页时仍是链 A。

```text
冷启 / 设置复查 / 抓页失败「去授权」
  App.SetupSnapshot.refresh
    → Agent.installedEngines / tuiPresence          （终端行）
    → HotKeyCenter 已注册结果                       （两行热键，只读）
    → PageAdmit.setupStatus                         （AX + 浏览器）
         → CapturePermissions.status
              AccessibilityPage.isTrusted
              NSWorkspace 已装 / 正在跑
              AutomationAccess.probe (ask=false)

人点「去授权 / 打开并授权」
  App
    → 若浏览器未跑：NSWorkspace 打开该 bundle（壳的事）
    → PageAdmit.requestAutomation(bundleID)
         → AutomationAccess.requestIfNeeded (ask=true)
    → 再 refresh

抓页失败条「去授权」
  App.openPrivacySettings
    → 同上要权；未开 AX 时仍打开辅助功能设置页
    → 要权后仍拒绝才打开自动化设置页

进货本身
  菜单栏 / 顶边 → Ingest.admit          链 A，卡挡不住
  ⌃⌥W / 菜单抓页 → PageAdmit.decide → admitCurrentPage   链 A
```

依赖方向不变：App → Ingest → Capture。App 不 import Capture。Agent / HotKey 仍只被 App 用。

### 内核契约

`DropAgentCapture`：

```text
enum AutomationState { allowed, denied, notDetermined, unavailable }

enum AutomationAccess {
  static func probe(bundleIdentifier:) -> AutomationState    // ask=false
  static func isAllowed(bundleIdentifier:) -> Bool           // probe == .allowed；现有调用点保持
  static func requestIfNeeded(bundleIdentifier:) -> AutomationState  // ask=true
}

struct BrowserAutomationRow {
  kind, bundleIdentifier, installed, running, state
  var allowed: Bool { state == .allowed }
}

struct CapturePermissionStatus {
  accessibilityTrusted: Bool
  browsers: [BrowserAutomationRow]   // 只含 installed == true 的 AppleScript Kind
}

enum CapturePermissions {
  static func status(...) -> CapturePermissionStatus   // 探测用依赖可注入，供 Check
  static func liveStatus() -> CapturePermissionStatus
}
```

`isAllowed` 保持 `Bool`，避免掀开所有抓页调用点。新 UI 走 `state`。

`DropAgentIngest.PageAdmit` 增：

```text
static func setupStatus() -> CapturePermissionStatus
static func requestTrustIfNeeded()            // 已有
static func requestAutomation(bundleIdentifier:) -> AutomationState
```

`decide` / `failure` / 冻结前台不变。

### App 契约

`SetupSnapshot`（App，无新包）：拼终端 + 热键 + `PageAdmit.setupStatus()`。

`SetupCardPolicy`（纯函数，可测）：

```text
shouldShowCard(dismissed:captureReady:isDiagnostic:panelVisible:requested:)
captureReady(status:)
gearNeedsAttention(hasAgent:status:)
```

`AppPreferences.setupCardDismissed`。

新视图：`SetupCard`（就绪卡）、`SettingsPane` 顶部一块复用同一行视图（例如 `SetupChecklist`），避免两套文案。

打开浏览器、打开系统设置深链仍在 App。

### 主线程与等待

`requestIfNeeded` 会等系统框。从 SwiftUI 按钮进 `Task { @MainActor in ... }`，该行 `authorizing == bundleID` 期间禁用。先 `hideForPrompt`，再在主线程 `requestAutomation`（`ask=true` + 只读 ping）。不要把 `ask=true` 丢到后台线程后再 `MainActor.run` 等回来。探测路径禁止 `ask=true`。

### 产品文档（执行时改，规则以本 spec 为准）

- `01-requirements.md`：第一次打开可见就绪卡；可跳过；无 CLI 仍能暂存。
- `02-prototype-design.md`：设置增加使用准备；就绪卡盖住左右栏。
- `03-tech-architecture.md`：Capture 公开权限探测 / 要权；App 不直接 import；注明不是第五链。
- `design/modules/app-shell.md`、`ingest.md`、`capture.md`：上表 public。
- `PRODUCT.md`：首次打开的就绪检查。
- `prototype/index.html`：卡 + 设置清单，文案与 App 同一套事实。

## 输入输出与依赖

输入：AX 信任、各浏览器已装/在跑/自动化状态、`installedEngines`、热键注册结果、`prefs.setupCardDismissed`、是否诊断启动、面板是否可见。

输出：是否显示卡、齿轮墨点、系统 AX 框、系统「控制 {浏览器}」框、必要时打开该浏览器、失败时才打开自动化设置页、`prefs.json` 的 dismiss 键。

依赖：现有 `PageAdmit`、`HotKeyCenter.register` 返回值、`Agent.installedEngines`、`AppPreferences`、first-open 面板展开。不改 Shelf / Job / TUI / Pasteboard 签名。

## 文件 / 模块边界

| 层 | 路径 |
|----|------|
| Capture | `AutomationAccess.swift`（可新 `CapturePermissions.swift`） |
| Ingest | `PageAdmit.swift` |
| App | `SetupCard.swift` / `SetupSnapshot.swift`（名称可合）、`SettingsPane.swift`、`AppPreferences.swift`、`AppSession.swift`、`PanelRootView.swift`、`AppDelegate.swift`、`Copy.swift`、`AppE2E.swift`、`PanelPreview.swift` |
| Check | `macos/Check/main.swift` |
| 原型 / 事实源 | `prototype/index.html`、`01`、`02`、`03`、`design/modules/{app-shell,ingest,capture}.md`、`PRODUCT.md` |
| 本 spec | `specs/cold-start-setup/spec.md` |

禁止：Utils 包；App import Capture；把 dismiss 写进 `settings.json`（那是 Agent 引擎）；为未装的浏览器造行。

## 并行分组

共享 `PageAdmit` / `AutomationAccess` / `AppPreferences` / `SettingsPane` / `PanelRootView`，默认**串行**。契约稳定后原型可与 App 视图并行，但主对话只一个 writer。

1. **probe-and-request**（内核）：`AutomationState`、`CapturePermissions`、`PageAdmit.setupStatus` / `requestAutomation`；Check 注入用例；探测不弹窗、要权 API 对不存在的 bundle 2 秒内返回。
2. **authorize-recovery**（壳的抓页失败）：`openPrivacySettings` 按上面 1–3 步；现有失败文案保留。
3. **setup-surfaces**（壳 UI）：policy、prefs、就绪卡、设置块、齿轮墨点、前台回前台刷新；预览 `13-setup` / `13-settings-setup`。
4. **docs-prototype**：`01/02/03`、模块文、原型、PRODUCT。
5. **verify**：Check、`--e2e` 策略断言、预览图。真机 TCC 不进 e2e。

1 完成后才能合 2 和 3。4 可与 3 交错，但文案以 Copy / 本 spec 为准。

## 验收标准

第一次打开面板看得到空架子和第一拍，不自动出就绪卡。抓页未齐时第二拍有授权。点「去准备」才出卡。头仍在。
2. 卡开着时拖到菜单栏图标或顶边，条目仍进架子。
3. 无 CLI：卡上终端行说明可先放架子，有如何安装；不阻止以后再说。有 CLI：绿，展示短名，不弹窗。
4. 辅助功能已开时点浏览器「去授权 / 打开并授权」：系统出现 DropAgent 控制该浏览器的对话框（真机）。允许后该行变绿。之后系统设置 → 自动化里能看到 DropAgent，并带该浏览器开关。
5. 已允许的行再点不重复弹窗。
6. 目标浏览器未运行：按钮是「打开并授权」，会先打开该浏览器再要权；8 秒仍未跑起来则不标绿。
7. 抓页失败条「去授权」在 AX 已开时走要权，不再只打开一个没有 DropAgent 的自动化页。拒绝后才打开自动化页。
8. 设置「使用准备」与卡同一套行。dismiss 之后齿轮在未齐时有墨点；全齐或仅热键占用则无墨点。
9. 权限被系统关掉后，卡不自动再弹出；设置清单和墨点更新；抓页失败条仍能要权。
10. `--e2e` / `--preview` / `--capture` 不自动出卡、不写 `setupCardDismissed`。`--e2e` 断言 `SetupCardPolicy`：未 dismiss + 未齐 + 非诊断 → 显示；dismiss 或诊断 → 不显示。预览含就绪卡与设置清单图。
11. Check：注入的 `CapturePermissions.status`（未装 Chrome 不出行、Arc 不出行、Safari 已装出现、全允许则 captureReady）；`requestIfNeeded` 对不存在的 bundle 不挂起；`AppPreferences` 缺键视为未 dismiss。
12. 四条调用链、App 不 import Capture、first-open 的 `opened` 语义均不变。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
# 真机要权（不进 e2e）：
DROPAGENT_ROOT=/tmp/dropagent-setup-live macos/.build/debug/DropAgent
# 应用包身份（自动化列表显示 DropAgent 而不是裸二进制）：
bash macos/package-app.sh
DROPAGENT_ROOT=/tmp/dropagent-setup-app macos/dist/DropAgent.app/Contents/MacOS/DropAgent
```

真机清单：辅助功能关着时点卡上「去授权」应出 AX 提示；Chrome 开着时点「去授权」应出控制 Chrome 框；系统设置自动化出现 DropAgent → Google Chrome。用 `dist/DropAgent.app` 验列表名称。

## 假设与开放问题

- 已验证（本机 2026-09-07）：正在跑的 Chrome 是 `com.google.Chrome`（pid 在跑、`/Applications/Google Chrome.app`）。`urlForApplication` 对大小写两种都能解析。`ask=false` 对 `com.google.Chrome` / `com.google.chrome` 都是 `-1743`，对已允许的 Safari 是 `0`。自动化列表只有 Safari、没有 Chrome，是要权没落表，不是 Chrome 没开。
- `AEDeterminePermissionToAutomateTarget(true)` 不够时，同进程只读 Apple Event 补上；禁止 `osascript`。
- 从 App bundle 启动时 TCC 显示名为 DropAgent。`swift run` / 裸 `macos/.build/debug/DropAgent` 是另一份 adhoc 身份——真机验收以 `dist/DropAgent.app` 为准。重签会换 CDHash，辅助功能列表里旧开关不算新这份。
- 屏幕录制不进本项清单。若内部试用发现截图总失败且系统要屏幕录制，另开 spec。
- 不在本项做快捷键改键。占用只展示。
- 多份 Chrome（用户数据目录）仍按 `capture-chrome-instance`：多实例不跑 AppleScript。就绪卡仍可对主 bundle 要权；不在本项重做多实例策略。
