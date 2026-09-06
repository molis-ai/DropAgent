# 源码和配置进架子不要当成 Markdown 文稿来渲染

## 背景目标

`01` 收纯文本。`kind(for:)` 把 `public.plain-text` / `public.text` 收成 markdown。`.swift` / `.py` / `.yaml` / `.xml` / `.css` 会标 **MD**、类型「文稿」，点「结果」走 `resultMarkdown`。源码里的 `*x*` 会变成斜体，YAML 会被拆成段。JSON 已经 pretty-print；这一刀把其余非散文文本也看真。

仍是 markdown kind：总结 / 抽取 / 发给 TUI 还能用。不改成 `file`（那样结果页只剩「拖出打开」）。

## 当前行为与问题证据

`displayTag`：除 `.json` 外，markdown 一律 `MD`。`resultBody`：未跑 markdown 一律 `resultMarkdown`。Check 没覆盖 `.swift` / `.yaml`。

## 范围

- 标签：`.md` / `.txt` / `.markdown` 仍是 `MD`；`.json` 仍是 `JSON`；其余 1–5 位扩展名用大写扩展名（`SWIFT` / `YAML` / `XML` / `CSS` / `PY`）。
- 结果页：JSON 仍 pretty-print；md/txt 仍 Markdown；其余未跑文稿用等宽原文，不走 Markdown。
- Check：`main.swift` kind 是 markdown、标签 `SWIFT`；`config.yaml` 标签 `YAML`。
- `--e2e` 验 `StagedPreview.mode`。
- 预览 `20-source`：能读到 SWIFT 标签和源码行，不是斜体 Markdown。
- 不改四条调用链、不改 Recipe 接受表。

## 非目标

- Developer ID。
- 不做语法高亮。
- 不把 yaml/xml 改成 `file`。

## 使用场景

拖进 `AgentService.swift`。架子上是 SWIFT，不是 MD。点「结果」看到原文。再发给 Grok 或跑总结。

## 方案与关键决策

kind 仍是 markdown（这是文本）。只改展示：标签和结果渲染。判定放在 App 的 `StagedPreview`；标签在 `Item.displayTag`。

## 输入输出与依赖

输入：本地文本文件 URL。输出：标签字符串、结果页 mode。依赖现有 Inbox 复制。

## 文件 / 模块边界

- `macos/Packages/DropAgentShelf/Sources/Item.swift`
- `macos/App/StagedPreview.swift`
- `macos/App/PanelRootView.swift`
- `macos/App/PanelPreview.swift`
- `macos/App/AppE2E.swift`
- `macos/Check/main.swift`
- 本 spec

## 验收标准

1. Check：`main.swift` kind markdown、`displayTag == "SWIFT"`；`config.yaml` 标签 `YAML`；`note.md` 仍是 `MD`。
2. `--e2e`：`note.md` → markdown；`data.json` → json；`main.swift` / `config.yaml` → code。
3. 预览 `20-source` 能读到 SWIFT 和源码。
4. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

类型字仍是「文稿」，因为 Recipe 把它们当文本。只改标签，避免和 `file` 的「文件」打架。
