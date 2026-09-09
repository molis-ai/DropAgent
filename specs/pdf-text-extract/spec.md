# PDF「文字提取」：本机抽可选中文字

## 背景与目标

选中 PDF 时增加和图片同类的本机动作「文字提取」。用系统 PDFKit 读副本里已经嵌着的字，写出可预览、复制、拖走的 `pdf.md`。不调用终端 Agent，不接云端，不把页面画成图再 OCR。

## 当前行为与问题证据

「文字提取」只接受图片。PDF 的「转换为 Markdown」走 CLI Agent。内容台对 PDF 只提示拖出打开。PDFKit 已能读部分内嵌文字，但没有交文件。

## 范围

- 选中项都是 PDF 时，动作栏出现「文字提取」。
- 确认后复制进任务目录，本机抽字，结果进结果区；原件 Hash 不变。
- 没装 Agent 也能跑。确认条：读副本、写任务目录、网络关、本机抽字不发送。
- 多页按「第 N 页」分开。整份都没有可选中文字时，产出里写明「这份 PDF 没有可选中的文字。」
- 打不开或有密码：任务失败，说清楚原因。

## 非目标

- 不把 PDF 页渲染成图再走 Vision（那是扫描件 OCR）。
- 不内置 MarkItDown / Python / 云端 Document Intelligence。
- 不进轮盘。不改「转换为 Markdown」的 CLI 路径。
- 图片 + PDF 混选不出现该按钮。

## 用户场景

拖入一份 Word 导出的 PDF → 点「文字提取」→ 确认 → 结果区出现 `pdf.md`，可预览和拖走。左边原件还在。扫描件会得到「没有可选中的文字」，而不是假装转成了排版完整的 Markdown。

## 方案与关键决策

新 Recipe `pdfText`。`requiresAgent = false`。Job 仍走副本 / Hash / `output/`，抽字用 PDFKit，不 `Agent.run`。按钮短名与图片相同（「文字提取」），全名「提取 PDF 文字」。无语言选项。

## 输入输出与依赖

输入：`ItemKind.pdf` 的副本。输出：`pdf.md`。依赖 macOS PDFKit。取消：当前文件抽完后停下，不写结果。

## 文件或模块边界

- `macos/Packages/DropAgentJob/`（catalog、PDFText、JobService）
- `macos/App/`（Chooser、Copy、确认条、e2e）
- `01-requirements.md`、`02-prototype-design.md`、`design/modules/job.md`、`prototype/index.html`

## 验收标准

1. 非 PDF 不出现该按钮；图片仍走原来的 Vision「文字提取」。
2. 没装 Agent 时，PDF 仍可提取。
3. Check：带字的 PDF 跑完，`pdf.md` 含标记字，原件字节不变，不调 Agent。
4. Check：空白 PDF 写出「没有可选中的文字」；损坏文件失败；图片拒绝。
5. `--e2e`：无 CLI 门禁下走通，结果可拖出。
6. 确认条不写 Workspace / 不说已关沙箱。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```
