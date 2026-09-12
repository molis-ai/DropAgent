# 模块：AppShell

包：`macos/App`（不是 Packages 里的内核）。

## 做什么

菜单栏图标、面板窗口、全局快捷键、把系统拖入事件判到「文件行 / 对话区 / 图标」、把用户点击接到内核。

## 不做什么

不持有 Item 列表真相（那是 Shelf）。不算 Hash。不拼 Recipe Prompt。不读浏览器。不自己 `NSPasteboard` 填 UTI（交给 Pasteboard 模块）。

## Public（对 App 内部 View 暴露的编排，不是给别的包）

| 动作 | 调用 |
|------|------|
| 图标 / 轮盘·加入材料 / 面板 drop | `Ingest.admit` / `admitPasteboard` / `admitProviders`，http(s) 再 `captureDroppedPages` |
| 轮盘·发给 | `Ingest.admit(..., capturePages: false)` 然后立刻 `TUI.send` |
| 轮盘·Recipe | `Ingest.admit` 然后立刻 `Job.start`（默认选项，不确认、不弹面板） |
| 粘贴 | `Ingest.admitClipboard()` |
| 别处复制的本地文件 | 盯系统剪贴板，`ClipboardStaging.filesToAdmit` 后 `Ingest.admit(urls:)` |
| 抓页快捷键 | `PageAdmit.snapshot` / `decide`，通过后 `Ingest.admitCurrentPage` |
| 加入选中文件 | 先钉死前台，再 `FrontAdmit.collect` → `Ingest.admit(urls:)` |
| 就绪卡 / 去授权 | `PageAdmit.setupStatus` / `requestTrustIfNeeded` / `requestAutomation`。第一次打开不自动出卡；人点「去准备」或设置里要权。 |
| Recipe 确认 | `Job.start(itemIDs:recipe:)` |
| 发送 | `TUI.send(itemIDs:text:)` |
| 拖出 / 复制 | `Pasteboard.export` / `copy` |
| 隐藏 | `Shelf.remove` / `removeResults`（列表拿掉，文件还在） |
| 删除 | `Ingest.deleteOwnedCopy` / `Job.deleteOwnedOutput`（只清 Inbox / Jobs 里自己的文件） |

轮盘出现后，其中心到六瓣的路径、上方按钮与主面板重叠时仍由轮盘拥有；不唤醒或避让重叠面板，松手按轮盘动作处理。离开既有外圈容差范围后轮盘取消，主面板正常接货。从主面板内开始的拖动不呼出轮盘。见 `specs/wheel-finder-route/spec.md`。

## 窗口

- `NSStatusItem` 靠右。启动和激活时钉住显示，不允许 Command 拖走；授权弹窗不藏 extra。挤满的菜单栏仍可能进系统折叠。
- 固定高度文件工作台：左目录分材料／结果／剪贴板，右侧预览，指令常驻下方。原文对照按需展开。状态变化不改变外窗大小，遵循 `specs/linear-workbench/spec.md`、`specs/sidebar-tree-actions/spec.md`、`specs/panel-drop-shelf/spec.md` 与 `specs/workbench-e2e-fixes/spec.md`。顶栏拖动、Agent、设置和窗口行为保留；搜索框固定在目录顶部，可过滤架子并添加本机文件，文件相对目录名缩进，行尾按钮代替右键。外部文件拖进面板任意处加入材料。
- 人离开后面板闲时：透明度约 0.72 并降到普通窗口层级，让开底下的 App。点还露着的面板、把文件拖进面板区域、图标或开合快捷键会醒；闲时点图标是唤醒不是关。从面板拖出时不闲时。点 + 选文件时面板不收起，选择窗在前面。诊断启动不闲时。
- 面板挂在当前桌面打开：用 `moveToActiveSpace`，不粘所有 Space，也不钉在第一次出现的桌面。切走后窗口留在原桌面；新桌面再打开会把窗口挂过来。
- 第一次打开显示空架子与欢迎区，直接通过示例 PDF 进入本机提取流程；授权在按需设置里。设置导航是权限与连接、快捷动作、快捷键、使用指南、Agent 与存储、外观。示例生成属于 App；仍走 Ingest → Job → Pasteboard，不新增业务调用链。
- 内容台使用原生 PDFKit；可编文字在预览顶栏用带纸面细边的「编辑副本」文字按钮进入。确认与运行保留预览，结果与剪贴板聚焦时禁用材料动作。错误恢复入口仍可见。
- 内嵌 PTY 在对话区里，不开独立桌面窗口。
- 评审用场景按钮只存在于 HTML 原型，正式 App **不带**。

## 扩展

新快捷键、新菜单项只加这里。终端引擎选择只写 App 设置并调用 Agent 探测。禁止为了方便把 Shelf 单例塞进每个 View。

## 壳内文件

`AppDelegate` 装配窗口、菜单栏、快捷键（`AppDelegate+Panel` / `+StatusItem`）。拖放轮盘是 `EdgeDropController`。Views 只跟 `AppSession` 说话。

`AppSession` 是唯一 ObservableObject 装配点，方法按调用链拆文件：

| 文件 | 链 |
|------|----|
| `AppSession+Admit.swift` | A 进货 |
| `AppSession+Job.swift` | B 副本 Recipe |
| `AppSession+TUI.swift` | C 发给 TUI |
| `AppSession+Export.swift` | D 拿走 |
| `AppSession+Shelf.swift` | 选中、隐藏、删除（挂在架子上，不是第五条链） |
| `AppSession+Capture.swift` | A：抓页 |
| `AppSession+FrontFiles.swift` | A：加入选中文件 |
| `AppSession+Setup.swift` | 授权门禁（挂在 A 上，不是第五条链） |
| `AppSession+Settings.swift` | 设置、快捷键、工作区 |

面板：`PanelRootView` 拼 `PanelHeader` / `WorkbenchSidebar` / `WorkbenchDetail`；详情挂 `ContentStage` / `RecipeChooser` / `WorkPane` / `AIPane`。
