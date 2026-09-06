# 拖进 .html 不要冒充文稿；未跑的 JSON 按 JSON 看

## 背景目标

`rtf-file` 记下 html/json 仍走 `.text` → markdown。拖进 `.html` 会变成 MD 文稿，结果页按 Markdown 渲染一堆标签。拖进 `data.json`，`displayTag` 已是 JSON，正文却被 `resultMarkdown` 糊成一段。Job 产出的 `extracted.json` 已经 pretty-print，未跑的 JSON 没有。

## 当前行为与问题证据

`public.html` / `public.json` 符合 `public.text`，不符合 `plainText`。`kind(for:)` 因此返回 markdown。`resultDocument` 只对 `output` 的 `.json` 做 pretty。

## 范围

- 本地 `.html` / `.htm` → `file`，标签 `HTML` / `HTM`。不做 HTML 阅读器。
- 未跑且 kind 是 markdown、正文是 JSON：结果页用和 Job JSON 相同的 pretty-print，不用 Markdown。
- Check：html 进 file；剪贴板 HTML 若抽成字仍按现有 CLIP 走（本刀不改剪贴板）。
- 预览加 `19-json-staged`：未跑 compact JSON 能看出字段，不是糊成一行。
- 不把 yaml / xml / css 一并改掉。

## 非目标

- Developer ID。
- 不把 JSON 改成 kind `file`（那样就不能在结果页看正文，也丢掉总结/抽取）。
- 不做 HTML 转 Markdown 阅读器。

## 使用场景

拖进保存的网页 `报价.html`：架子上是 HTML 文件，翻译是暗的，拖出用浏览器打开。拖进 `extracted.json`：点「结果」看到缩进后的字段，再决定发给 Grok。

## 方案与关键决策

html 按扩展名进 file，与 rtf 同一条判定链。JSON pretty 抽到 App 的 `ResultJSON`，Job 产出和未跑文稿共用，避免两套格式化。

## 输入输出与依赖

输入：本地 html URL；markdown Item 的正文。输出：kind file 或 pretty JSON 字符串。

## 文件 / 模块边界

- `macos/Packages/DropAgentIngest/Sources/IngestService.swift`
- `macos/Check/main.swift`
- `macos/App/ResultJSON.swift`
- `macos/App/PanelRootView.swift`
- `macos/App/PanelPreview.swift`
- `macos/App/AppE2E.swift`
- `design/modules/ingest.md`
- 本 spec

## 验收标准

1. Check：`page.html` 进货 kind 是 file，`displayTag` 是 `HTML`。
2. `--e2e`：compact 对象 pretty 后含换行和字段名；不是 Markdown heading。
3. 预览 `19-json-staged` 能读到 JSON 字段。
4. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

xml / yaml / css 仍是 markdown kind，结果页按等宽原文看，见 `specs/staged-source`。
