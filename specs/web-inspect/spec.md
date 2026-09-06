# 网站条点开看链接、正文、截图

## 背景目标

`02` 要求网站条「点开能看链接、正文、截图」。现在这三样塞在「动作」里：截图最高 96pt、正文最多 8 行，六个 Recipe 被挤到下面。未跑过的 WEB「结果」是灰的；已进终端的 WEB 点「结果」只写「材料已送进终端」，看不到页。

## 当前行为与问题证据

预览 `07-web`：动作区同时有 URL、蓝截图、Recipe 网格。「结果」对 idle WEB 不可点。`currentResult()` 只认 done / failed / sent；sent 的 `resultBody` 不走 `webMaterials`。

## 范围

- 选中网站条时「结果」可点，里面看链接、Markdown 正文、截图。已进终端的同样能看，另写一句可去「终端」。
- 「动作」对单条网站只留一行 URL（有抓取失败再留警告）和「点「结果」看正文和截图。」六个 Recipe 仍在动作区。
- 单击 idle WEB 仍停在「动作」（Recipe 是主路径），不自动切「结果」。
- 预览：`07-web` 动作区看得到 Recipe；新增 `07b-web-result` 能读到 example.com、正文、截图。

## 非目标

- 不给 PDF / 图片做阅读器。
- 不改 Capture、Ingest、Pasteboard 拖出文件夹。
- 不改四条调用链。
- Developer ID。

## 使用场景

人刚用 ⌃⌥W 抓了一页，想先确认正文和截图在，再决定发给 Grok 还是跑 Recipe。点「结果」看材料，回「动作」选动作。

## 方案与关键决策

`currentResult()` 在 done / failed / sent 之后，再认选中的 `kind == .web`。动作区不再铺开 `webMaterials`。结果区对 WEB 用完整材料；有 Markdown 就按标题/列表显示。

## 输入输出与依赖

输入：架子上的 WEB（`url.txt` / `page.md` / `snapshot.png` 缺哪样显示哪样）。输出：只改面板。依赖 Shelf 快照，不新读浏览器。

## 文件 / 模块边界

- `macos/App/AppSession.swift`：`currentResult()`
- `macos/App/PanelRootView.swift`：动作压缩、结果展开
- `macos/App/PanelPreview.swift`：`07-web` / `07b-web-result`
- `design/modules/ai-pane.md`、`02-prototype-design.md`：结果 Tab 含网站材料
- 原型与正式 App 对齐，不发明新规则

## 验收标准

1. 预览 `07-web`：动作 Tab；看得到「总结」等 Recipe；没有大截图压住按钮；有「点「结果」看正文和截图。」
2. 预览 `07b-web-result`：结果 Tab；能读 `https://example.com`、正文句子、截图。
3. 已进终端的 WEB 点「结果」仍能看到材料，不是只剩一句「已送进终端」。
4. Check 全绿；四条调用链不变。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
```

## 假设与开放问题

无。单击 WEB 不自动切结果，避免挡 Recipe。
