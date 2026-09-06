# 网站结果先看到截图

## 背景目标

`02`：网站条点开能看链接、正文、截图。结果区现在先铺 Markdown（表、代码、引用），截图 `maxHeight: 140` 排在最后。预览 `07b-web-result` 和真抓 example.com 时，400px 面板要滚才看得到是哪一页。拿走按钮已经钉住，截图没有。

## 当前行为与问题证据

`webMaterials` 顺序：链接 → 失败警告 → 正文 → `snapshot.png`。`07b` 的 `page.md` 含引用、图链、表、代码，截图被挤出首屏。`--e2e` 抓页后停在「动作」，没有结果页快照。

## 范围

- 结果 Tab 的网站材料：链接和警告仍在最上；有截图则紧跟其后；正文在截图下面。
- 动作 Tab 仍只留 URL +「点结果看正文和截图」，不把大图放回来。
- `--e2e` 真抓 example.com 后切「结果」，断言有 `page.md` 和 `snapshot.png`，并快照。
- 不改 Capture / Ingest / Pasteboard，不改四条调用链。

## 非目标

- 不把截图改成阅读器。
- 不改表格/引用解析。
- Developer ID。

## 使用场景

⌃⌥W 抓完一页，点「结果」先确认截图对，再读正文或拖走。

## 方案与关键决策

窄面板里「这是哪一页」比长 Markdown 更需要首屏。截图仍限高 140pt。

## 输入输出与依赖

输入：WEB 的 `url.txt` / `page.md` / `snapshot.png`。输出：只改结果区排列和 e2e 快照。

## 文件 / 模块边界

- `macos/App/PanelRootView.swift`
- `macos/App/AppE2E.swift`
- `macos/App/PanelPreview.swift`（`07b` 顺序随渲染变）
- 本 spec

## 验收标准

1. 预览 `07b-web-result`：结果区在正文表/代码之前能看到页面截图（蓝条 example.com）。
2. `--e2e`：Safari 抓 example.com 后结果 Tab 该条有 `url.txt`、`page.md`、`snapshot.png`。
3. 动作 Tab 仍无大截图。
4. Check 全绿；随后 Grok 发送仍过。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

截图失败、只有正文时，结果区仍从链接+正文开始，不留空图框。
