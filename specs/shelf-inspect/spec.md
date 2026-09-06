# 粘贴的字、链接、文稿、文件夹也能点开看

## 背景目标

⌘V 和拖链接是主进货口。WEB / 图片已经能在「结果」里看。CLIP、URL、未跑的 Markdown、文件夹选中后「结果」仍是灰的，人看不到刚贴进去的字。

## 当前行为与问题证据

`currentResult()` 只认 done / failed / sent / web / image。预览没有 CLIP / URL 的结果页。`ingest.md`：`http(s)` 只进链接，不自动抓正文。

## 范围

- 选中 CLIP / URL / 未跑的 Markdown / 文件夹 / PDF，「结果」可点。
- CLIP、未跑 Markdown：显示正文，可选择。
- URL：显示链接；写明不会自动抓正文，抓页用 ⌃⌥W。
- 文件夹：列出里面的文件名（最多 12 个）。
- PDF：写「这是 PDF，拖出到其他应用打开。」仍可拖出。
- 单击 idle 仍停在「动作」。动作区一行提示去「结果」。
- 预览 `15-clip` / `15b-clip-result`、`16-url` / `16b-url-result`、`17-folder` / `17b-folder-result`。
- 预览 `03d-pdf-result`：PDF 结果页写明拖出打开。

## 非目标

- 不做 PDF 阅读器、不自动抓 URL 正文。
- 不改进货、抓页、拖出形态。Job 只补文件夹总结的核对，不改 Recipe 接受表。
- Developer ID。

## 使用场景

人 ⌘V 贴了一段口径，点「结果」确认是那段，再发给 Grok 或跑总结。拖进一个链接，先看见地址，要网页材料再按 ⌃⌥W。

## 方案与关键决策

`currentResult()` 在特化种类之后，回落到当前选中的第一条。动作区 peek 与 WEB/图片同一套。结果区读 `parts` 文本或列目录，不新读原件路径做 Hash。

## 输入输出与依赖

输入：架子上的 Item。输出：只改 App 面板。内核包不动。

## 文件 / 模块边界

- `macos/App/AppSession.swift`：`currentResult()`
- `macos/App/PanelRootView.swift`：peek / 结果
- `macos/App/PanelPreview.swift`：03d / 15 / 16 / 17
- `macos/Check/main.swift`：文件夹总结
- `design/modules/ai-pane.md`、`02-prototype-design.md`

## 验收标准

1. `15-clip`：动作 Tab，有「点「结果」看这段字。」Recipe 可见。
2. `15b-clip-result`：结果 Tab 能读到预览正文。
3. `16-url`：动作 Tab 看得到链接提示。
4. `16b-url-result`：结果 Tab 有 `https://` 地址，并写不用自动抓正文。
5. `17-folder`：动作 Tab 有「点「结果」看里面有什么。」
6. `17b-folder-result`：结果 Tab 能读到文件夹里的文件名。
7. Check：对文件夹跑「总结」会把目录拷进 work/，原件不动；抽取文件夹仍拒绝。
8. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
```

## 假设与开放问题

无。
