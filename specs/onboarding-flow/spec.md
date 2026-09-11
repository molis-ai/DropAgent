# 第一次打开：一次只问一件事

> 2026-09-11：本项涉及的首次流程、文案和组件样式由 [UI 与引导优化](../ui-onboarding-refresh/spec.md) 更新；原有业务与权限边界保留。


完成等级：4 内部完整（空根目录首次打开、分步引导、试一次、跳过、授权弹窗顺序、设置复查可内部试用）。不是可发布。

## 背景目标

aha 是：材料上架 → 选动作 → 下面出现新文件，原件不动。第一次打开要尽快把人带到这一下。

动线和气质对齐 GoalBoard Onboarding：一次只问一件事，上回声，进度点，描边箭头，随时可跳过。不是把全屏引导页塞进菜单栏，也不是新窗口。架子始终露在上面，人随时可以拖文件进来。

## 当前行为与问题证据

上一轮已把就绪卡从自动盖住架子改成按需出现，并把授权嵌进首次动作区。动作区仍是「一句标题 + 三列说明书 + 通栏主按钮 + 授权清单」，一次摊开。GoalBoard 的有效结构是对话：进度 `01 / 03 · 先放下`，下一步在问题上头，授权像选项行，最后才问要不要放示例。

## 范围

- 首次打开：架子可见。动作区是 GoalBoard 式对话，不是三列并排。抓页未齐时，授权是其中一拍，可跳过。已齐则跳过该拍。
- 就绪卡不再自动盖住面板。人点空态「去准备」或预览 / e2e 显式请求才出卡。
- 跳过任一步后若抓页未齐且未 dismiss：动作区一条横条，不盖架子。
- 试一次：仍走链 A 写入 `先读我.md`。文稿是可总结的短备忘。选中后动作栏一句引导。
- 辅助功能「允许」：藏面板、要权。不同时打开设置。身份对不上才打开辅助功能页。
- 浏览器 / Finder：一次一个。拒绝后才打开自动化设置。
- 原型「第一次」跟正式 App 同一套事实。

## 非目标

- 新窗口、教练聚光灯、示例 PDF、自动跑 Recipe。
- 把整块面板换成 GoalBoard 的灰绿纸面。纸面仍是 DropAgent 冷白 `#fcfcfd`，强调色 `#365cda`。
- 改快捷键组合、重映射被占用的键。
- 屏幕录制。Developer ID。
- 把工作区路径 / 颜色 / 语言塞进冷启。
- 要求所有已装浏览器都授权才算抓页就绪。

## 使用场景

1. 第一次双击：面板出来，上面是空架子。下面是 `01 / 03 · 先放下` 和一句「这是一个架子。」点「下一步」。
2. 第二拍「抓网页还差授权。」选项行是辅助功能 + 已装浏览器。点「允许」只出系统框。不授权也可以点「下一步」。
3. 第三拍回声上一圈，问「要不要先放一份示例？」点「放入示例 →」上架 `先读我.md`。右上「跳过」随时可走。
4. 抓页已经齐：只有两拍，没有授权那一拍。
5. 放入示例后动作栏一句「选一个动作试试…」。选「总结」后引导消失。不自动运行。
6. 点「跳过」：对话收起。未齐时动作区一条「抓当前页还差授权」。点「以后再说」进空架子，齿轮留墨点。

## 方案与关键决策

### 动线

```text
first-open 弹出面板
  → 架子可见 + 对话（showsOnboarding）
       01 这是一个架子
       02 抓页授权（未齐才有；可跳过）
       03 要不要放示例
  → 放入示例：示例上架 + 动作栏一句
  → 跳过 / 已有条目：对话不再出现
       空且未齐且未 dismiss：动作区横条
       点「去准备」：就绪卡（人要的）
  → 设置「使用准备」：完整分组清单
```

系统对话框：一次一个。

### 一拍的结构（GoalBoard）

```text
[ 5px 色点  01 / 03 · 先放下 ]     [跳过]  [上一步] [下一步 →]
（从第二拍起）5px 色点 + 回声
h1 一句
intro 一句
本拍内容（授权行 / 三行回看）
```

- 进度用等宽小写、字距、大写；序号本身说明现在在哪一拍。
- 下一步 / 上一步 / 放入示例是文字加箭头，不是实心胶囊。
- 跳过始终在进度行右侧。
- 授权行像 GoalBoard 的 runtime 选项：一行名字、右侧 5px 点，悬停浅底。不堆卡片。

抓页未齐的路径在第一次出现时钉死。中途授权齐了仍停在该拍，点下一步才到示例。已齐的人从一开始就没有这一拍。

### 何时出就绪卡

```text
shouldShowCard = !isDiagnostic && panelVisible && !dismissed && !captureReady && requested
```

`requested` 是本次进程里的显式请求，不写盘。dismiss 仍写 `prefs.setupCardDismissed`。

`captureReady` 不变：辅助功能已开，且至少一家已装 AppleScript 浏览器已允许。

### 文案原则

先说要做什么。第一眼不出现可执行路径、不说「当前进程」。拖文件不需要授权，这句话只在抓页那一拍出现。

## 输入输出与依赖

输入：架子是否为空、`onboarded`、`firstActionHintDismissed`、AX / 浏览器 / Finder / CLI / 热键、`setupCardDismissed`、是否诊断、面板是否可见、是否请求就绪卡、本进程的引导拍。

输出：分步对话、示例条目、动作栏引导、抓页横条、就绪卡、系统 AX 框、系统控制浏览器 / Finder 框、必要时打开系统设置、`onboarded` 标记、`prefs` 的 dismiss 与提示键。

依赖：现有 `Ingest.admit`、`PageAdmit`、`SetupCardPolicy`、`HotKeyCenter`、first-open。不改 Shelf / Job / TUI 签名。

## 文件 / 模块边界

- `macos/App/Onboarding.swift` / `OnboardingView.swift`
- `macos/App/SetupCard.swift` / `SetupSnapshot.swift`
- `macos/App/AppSession.swift` / `AppSession+Setup.swift` / `AppSession+Facts.swift` / `AppSession+Job.swift`
- `macos/App/AppPreferences.swift` / `WorkPane.swift` / `RecipeChooser.swift`
- `macos/App/AppE2E.swift` / `PanelPreview.swift`
- `prototype/index.html`
- `01-requirements.md` / `02-prototype-design.md` / `PRODUCT.md`
- `specs/onboarding/spec.md` / `specs/cold-start-setup/spec.md`
- 本 spec

禁止：Utils 包；App import Capture；自动跑 Recipe；为未装浏览器造行。

## 验收标准

1. 空 `DROPAGENT_ROOT`、非诊断、抓页未齐：第一次打开看得到空架子和第一拍「这是一个架子。」，不自动出盖住架子的就绪卡。进度为 `01 / 03`。
2. 未齐时第二拍是抓页授权行（辅助功能 + 已装浏览器），写明拖文件不需要这些。不授权也可以下一步。已齐则没有这一拍，进度为 `01 / 02`。
3. 最后一拍主操作是「放入示例」，不是通栏实心按钮。试一次：架子上有可总结的 `先读我.md`；对话消失；动作栏有引导；不写 `opened`。点动作或「知道了」后引导不再出现。
4. 任一步点「跳过」：对话不再出现。未齐时动作区有横条；「以后再说」后再开面板不出横条、不出卡。
5. 点「去准备」才出就绪卡。头仍在。菜单栏 / 顶边拖入仍进货。
6. 辅助功能要权：系统出现辅助功能提示，不同时打开设置（foreign copy 除外）。浏览器要权：系统出现控制该浏览器的对话框；已允许再点不弹；拒绝后才打开自动化页。
7. 设置「使用准备」分组与卡同一套行；未开辅助功能才显示应用路径。
8. `--e2e` / `--preview` / `--capture` 不自动出卡。e2e 断言：未请求 → 不出卡；请求 + 未齐 + 非诊断 → 显示。预览 `00-onboard` 为第一拍；`00-onboard-capture` 为授权拍；`00-onboard-try` 为示例拍；`00-banner` 为跳过后横条；`13-setup` 为请求后的卡。
9. Check 全绿。四条调用链、`opened` 语义不变。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
DROPAGENT_ROOT=/tmp/dropagent-setup-live macos/.build/debug/DropAgent
bash macos/package-app.sh
DROPAGENT_ROOT=/tmp/dropagent-setup-app macos/dist/DropAgent.app/Contents/MacOS/DropAgent
```

## 假设与开放问题

- 沿用冷启的要权实现。本项改动线和表面，不重做探测。
- 辅助功能系统提示在较新 macOS 上主按钮是「打开系统设置」。所以 App 不再抢先打开同一页。
- 真机 TCC 不进 e2e。
- 引导拍只存在本进程，不写盘。关面板再开、尚未 onboarded 时从第一拍开始。
