# 模块：AppShell

包：`macos/App`（不是 Packages 里的内核）。

## 做什么

菜单栏图标、面板窗口、全局快捷键、把系统拖入事件判到「左列表 / 右 AI / 图标」、把用户点击接到内核。

## 不做什么

不持有 Item 列表真相（那是 Shelf）。不算 Hash。不拼 Recipe Prompt。不读浏览器。不自己 `NSPasteboard` 填 UTI（交给 Pasteboard 模块）。

## Public（对 App 内部 View 暴露的编排，不是给别的包）

| 动作 | 调用 |
|------|------|
| 图标 / 顶边 / 列表 drop | `Ingest.admit` / `admitPasteboard` / `admitProviders`，http(s) 再 `captureDroppedPages` |
| AI 区 drop | `Ingest.admit(..., capturePages: false)` 然后立刻 `TUI.send` |
| 粘贴 | `Ingest.admitClipboard()` |
| 抓页快捷键 | `PageAdmit.snapshot` / `decide`，通过后 `Ingest.admitCurrentPage` |
| 加入选中文件 | 先钉死前台，再 `FrontAdmit.collect` → `Ingest.admit(urls:)` |
| 就绪卡 / 去授权 | `PageAdmit.setupStatus` / `requestTrustIfNeeded` / `requestAutomation` |
| Recipe 确认 | `Job.start(itemIDs:recipe:)` |
| 发送 | `TUI.send(itemIDs:text:)` |
| 拖出 / 复制 | `Pasteboard.export` / `copy` |

## 窗口

- `NSStatusItem` 靠右。
- 面板约 680pt 宽、620pt 高，贴图标下方；左列表、右 AI，中间可拖竖分隔条。左栏默认 240pt，可拖 200–320pt。头上关闭左边是最小化，都是藏面板，不是系统窗口缩小。
- 第一次打开若抓页权限未齐，就绪卡盖住左右栏（头仍在）。设置页最上面是同一张「使用准备」清单，下面是可改快捷键、「能做什么」（拖入 / 类型 / 浏览器 / 读 / 写 / 拖出）、工作区路径、Runtime、颜色、语言。
- 内嵌 PTY 在面板底部 Tab「终端」，不开独立桌面窗口。
- 评审用场景按钮只存在于 HTML 原型，正式 App **不带**。

## 扩展

新快捷键、新菜单项只加这里。终端引擎选择只写 App 设置并调用 Agent 探测。禁止为了方便把 Shelf 单例塞进每个 View。
