# 复制本地文件：直接进架子

## 背景目标

人在 Finder 或编辑器里复制文件，期望打开 DropAgent 就能在文件行 / 内容台看见。现在这份复制只进剪贴板历史（粘贴按钮后面），还要再 ⌘V 或从历史拖一次。文件应当进暂存区；字和图仍走剪贴板旁路。

完成等级：内部完整。

## 当前行为与问题证据

- App 盯 `NSPasteboard.general.changeCount`，`notePasteboard` 把文件、字、图都记进 `ClipHistoryStore`，不去架子。
- ⌘V / 粘贴按钮才 `admitPayload`。
- 「加入选中的文件」热键已经会进架子，但日常路径是 ⌘C，不是那条热键。

## 范围

- 系统剪贴板出现**存在的本地文件**（可多条，含文件夹）：走现有 `Ingest.admit(urls:)`，复制进写入区，原件不动。选中新进的条目，内容台能打开。
- 不因此打开或抢前台面板。下次打开面板就能看见。
- 这些文件**不**进剪贴板历史。系统剪贴板仍保留，别处还能粘贴。
- 字、图、http(s)、隐蔽类型：行为不变，仍只记历史（或忽略）。
- 本 App 把架子上的条目复制到系统剪贴板：仍只记历史，不重新进货。
- 「加入选中的文件」模拟 ⌘C 期间：不把这份临时剪贴板再进一次货，也不记进历史。
- 历史里双击文件条设为当前：不进货。
- 设置「能做什么」写清这条。⌘V 贴文件仍进货（DropAgent 没在跑时复制的，还能贴进来）。

## 非目标

- 不拦截系统 ⌘C，不改热键。
- 不把截图 / 纯文本 / 链接当成这次进货。
- 不做成剪贴板管理器，不当首页。
- 不自动跑 Recipe，不自动打开面板。
- 不为「刚复制过再 ⌘V」去重。

## 使用场景

在 Finder 里选中报价 PDF，⌘C。打开 DropAgent，文件行已有副本，点开能看内容。原件还在原地。把同一份 PDF 粘到邮件里仍然可以。

## 方案与关键决策

`ClipboardStaging.filesToAdmit`：只对外面的文件路径进货；Inbox / Jobs 里的副本视为本 App 复制。`notePasteboard` 在盯板时调用；进货成功则不 `ClipHistoryStore.record`。

## 输入输出与依赖

输入：系统剪贴板 changeCount + `ClipboardPayload.files`。输出：Shelf Item（Inbox 副本）。依赖现有链 A：`Ingest.admit(urls:)`。

## 文件 / 模块边界

- `macos/Packages/DropAgentIngest/Sources/ClipboardStaging.swift`
- `macos/App/AppSession+ClipHistory.swift`、`+Export.swift`
- `macos/Check/main.swift`、`macos/App/AppE2E.swift`
- `01-requirements.md`、`02-prototype-design.md`、`03-tech-architecture.md`、`PRODUCT.md`、`README.md`
- `design/modules/app-shell.md`、`ingest.md`、`pasteboard.md`
- `macos/App/SettingsGuideCopy.swift`、`prototype/index.html`

## 验收标准

1. Check：外部文件路径要进货；Inbox / Jobs 内路径不要；字 / 图 / suppress 时空列表。
2. `--e2e`：独立剪贴板写入本地文件再 `notePasteboard`，架子多一条副本，正文一致，原件不变，历史条数不增加。
3. `--e2e`：把 Inbox 里那份再 `notePasteboard`，不新增条目。
4. `--e2e`：设置「能做什么」含复制文件进架子的中英文。
5. 字 / 图的剪贴板历史与 ⌘V 仍过。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

复制很大的文件夹会按拖入同样整份进 Inbox。不弹确认。面板关着时人要打开才能看见内容台。
