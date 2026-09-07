# 架子：跟随系统语言、加号选文件、Spotlight 搜到加入

## 背景与目标

语言只有中文 / 英文，系统不是中文时仍默认中文。架子只能拖入或粘贴，窄栏里不好找本机文件。要能：语言跟随系统（非中文用英文）；列表上方用 + 选文件；用 Spotlight 搜本机文件并一键加入。加入仍走 Ingest 副本，原件不动。

## 当前行为

- `AppLanguage` 只有 `zh` / `en`，默认 `zh`。
- 列表顶栏只在有条目时出现「多选」。
- 没有 NSOpenPanel 选文件进架子，没有 `NSMetadataQuery`。

## 范围

- 语言增加「跟随系统」。系统首选语言以 `zh` 开头用中文，否则英文。新偏好默认跟随系统。
- 列表上方常驻一行：`+` 选文件或文件夹（可多选）→ `ingest.admit(urls:)`；Spotlight 搜索框。
- 输入至少 2 个字后搜本机文件，最多 24 条：先问 Spotlight（`mdfind`），索引空或只读时改扫桌面 / 文稿 / 下载 / 图片 / 影片 / iCloud Drive 的文件名。点行加入架子。空查询回架子列表。
- 有条目时「多选」仍在下一行。
- 不改四条调用链；复制进 Inbox，拒绝符号链接。

## 非目标

- 不改 Recipe / TUI / 抓页。
- 不把 Spotlight 结果当架子条目存盘。
- 不做全文内容搜索（只用显示名 / 文件名，避免把面板拖慢）。
- 不保证 /tmp 或未建立索引的盘能搜到。

## 文件边界

- `macos/App/AppPreferences.swift`、`Copy.swift`、`SettingsPane.swift`
- `macos/App/SpotlightSearch.swift`
- `macos/App/AppSession.swift`、`PanelRootView.swift`、`AppDelegate.swift`、`AppE2E.swift`
- `02-prototype-design.md`、`DESIGN.md`

## 验收

1. 设置语言三项：中文、English、跟随系统。跟随系统时非中文系统界面为英文。
2. 空架子也看得到 + 和搜索框。+ 选出的文件出现在架子上，原件还在。
3. 搜索「至少 2 字」能列出桌面/文稿/下载里文件名匹配的条目（不依赖 Spotlight 索引是否健康）；点一条即加入；清掉搜索回到架子。
4. Check 全绿；`--e2e` 含加号/搜索框、跟随系统语言、用 admit 加入文件。

## 验证

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```
