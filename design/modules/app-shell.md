# 模块：AppShell

包：`macos/App`（不是 Packages 里的内核）。

## 做什么

菜单栏图标、面板窗口、全局快捷键、把系统拖入事件判到「文件行 / 对话浮窗 / 图标」、把用户点击接到内核。

## 不做什么

不持有 Item 列表真相（那是 Shelf）。不算 Hash。不拼 Recipe Prompt。不读浏览器。不自己 `NSPasteboard` 填 UTI（交给 Pasteboard 模块）。

## Public（对 App 内部 View 暴露的编排，不是给别的包）

| 动作 | 调用 |
|------|------|
| 图标 / 轮盘·加入架子 / 列表 drop | `Ingest.admit` / `admitPasteboard` / `admitProviders`，http(s) 再 `captureDroppedPages` |
| 轮盘·发给 | `Ingest.admit(..., capturePages: false)` 然后立刻 `TUI.send` |
| 轮盘·Recipe | `Ingest.admit` 然后立刻 `Job.start`（默认选项，不确认、不弹面板） |
| AI 区 drop | `Ingest.admit(..., capturePages: false)` 然后立刻 `TUI.send` |
| 粘贴 | `Ingest.admitClipboard()` |
| 抓页快捷键 | `PageAdmit.snapshot` / `decide`，通过后 `Ingest.admitCurrentPage` |
| 加入选中文件 | 先钉死前台，再 `FrontAdmit.collect` → `Ingest.admit(urls:)` |
| 就绪卡 / 去授权 | `PageAdmit.setupStatus` / `requestTrustIfNeeded` / `requestAutomation` |
| Recipe 确认 | `Job.start(itemIDs:recipe:)` |
| 发送 | `TUI.send(itemIDs:text:)` |
| 拖出 / 复制 | `Pasteboard.export` / `copy` |
| 隐藏 | `Shelf.remove` / `removeResults`（列表拿掉，文件还在） |
| 删除 | `Ingest.deleteOwnedCopy` / `Job.deleteOwnedOutput`（只清 Inbox / Jobs 里自己的文件） |

## 窗口

- `NSStatusItem` 靠右。
- 面板默认约 1040pt 宽，高度随内容，贴图标下方。上面是「文件」横向卡，选中才出动作；再点取消选中；双击用系统默认方式打开。有结果才出「结果区」。点「其他」才在下方弹出「对话」浮窗，中间露出桌面。悬停预览贴在整个面板左侧：Markdown 可读渲染，HTML 抽正文，不嵌网页；离开卡片后约两秒内仍留着，指针在预览卡内不关，过长可上下滚，宽表和长代码可左右滑。文件行粘贴按钮在按钮旁展开面板风格的剪贴板下拉；⌘V 仍直接贴当前。顶栏：字标左、搜索中、芯片 / 设置 / 窗口按钮右。搜索下拉加入架子。头上关闭左边是最小化，都是藏面板。
- 人离开后面板闲时：变淡并降到普通窗口层级，让开底下的 App。点还露着的面板、把文件拖进面板区域、图标或开合快捷键会醒；闲时点图标是唤醒不是关。从面板拖出时不闲时。点 + 选文件时面板不收起，选择窗在前面。诊断启动不闲时。
- 面板挂在当前桌面打开：用 `moveToActiveSpace`，不粘所有 Space，也不钉在第一次出现的桌面。切走后窗口留在原桌面；新桌面再打开会把窗口挂过来。
- 第一次打开若抓页权限未齐，就绪卡盖住文件架（头仍在）。设置左右分栏：使用准备、快捷键、能做什么、本机、外观。外观可关拖放轮盘。准备好抓页不要求每一家已装浏览器都授权。
- 内嵌 PTY 在对话浮窗里，不开独立桌面窗口。
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

面板：`PanelRootView` 拼装 `PanelHeader` / `ShelfColumn` / 动作栏 / `ResultStack` / 对话浮窗（`AIPane`）。
