# 模块：AppShell

包：`macos/App`（不是 Packages 里的内核）。

## 做什么

菜单栏图标、面板窗口、全局快捷键、把系统拖入事件判到「上半 / 下半 / 图标」、把用户点击接到内核。

## 不做什么

不持有 Item 列表真相（那是 Shelf）。不算 Hash。不拼 Recipe Prompt。不读浏览器。不自己 `NSPasteboard` 填 UTI（交给 Pasteboard 模块）。

## Public（对 App 内部 View 暴露的编排，不是给别的包）

| 动作 | 调用 |
|------|------|
| 图标 / 顶边 / 列表 drop | `Ingest.admit(urls:)` / `admitPasteboard` / `admitProviders` |
| AI 区 drop | `Ingest.admit` 然后立刻 `TUI.send` |
| 粘贴 | `Ingest.admitClipboard()` |
| 抓页快捷键 | `PageAdmit.snapshot` / `decide`，通过后 `Ingest.admitCurrentPage` |
| Recipe 确认 | `Job.start(itemIDs:recipe:)` |
| 发送 | `TUI.send(itemIDs:text:)` |
| 拖出 / 复制 | `Pasteboard.export` / `copy` |

## 窗口

- `NSStatusItem` 靠右。
- 面板约 400pt 宽，贴图标下方；上列表、下 AI，中间可拖分隔条。空态约 140pt；有条目时贴行高（单行 56pt），可拖 56–320pt。切到终端时若高于贴合行高与 108pt 的较小值，先收到该高度，不写入偏好。
- 内嵌 PTY 在面板底部 Tab「终端」，不开独立桌面窗口。
- 评审用场景按钮只存在于 HTML 原型，正式 App **不带**。

## 扩展

新快捷键、新菜单项只加这里。终端引擎选择只写 App 设置并调用 Agent 探测。禁止为了方便把 Shelf 单例塞进每个 View。
