# 图片「文字提取」：本机 OCR 跑通

## 背景与目标

选中图片时增加「文字提取」。用系统 Vision 在副本上抽字，写出可预览、复制、拖走的 `ocr.md`。不调用终端 Agent，不接云端。

## 当前行为与问题证据

六个 Recipe 全部走 CLI。图片只能总结 / 抽取 / 转 MD，且没装可收口 CLI 时全禁用。本机 Vision 已能识别中英，产品没有入口。

## 范围与非目标

做：

- 选中项都是图片时，动作栏出现「文字提取」。
- 确认后复制进任务目录，本机识别，结果进结果区。
- 低置信度行标「待确认」。没有字就写明「没有识别到文字。」
- 原件 Hash 不变。没装 Agent 也能跑。
- 确认条：读副本、写任务目录、网络关、本机识别不发送。

不做：

- 不进轮盘（仍六瓣）。
- 不做 PDF OCR、手写专精、云端模型。
- 不改另外六个 CLI Recipe 的门禁。

## 用户场景

拖入一张截图 → 点「文字提取」→ 确认 → 右侧出现 `ocr.md`，可预览和拖走。左边原图还在。

## 方案与关键决策

新 Recipe `imageText`。`requiresAgent = false`。Job 仍走副本 / Hash / `output/`，识别用 Vision，不 `Agent.run`。选项：中英（默认）/ 中文 / 英文。

## 输入输出与依赖

输入：`ItemKind.image` 的副本。输出：`ocr.md`。依赖 macOS Vision。取消：当前图认完后停下，不写结果。

## 文件或模块边界

- `macos/Packages/DropAgentJob/`（catalog、ImageText、JobService）
- `macos/App/`（Chooser、Copy、确认条、e2e）
- `01-requirements.md`、`02-prototype-design.md`、`design/modules/job.md`、`prototype/index.html`

## 验收标准

1. 非图片不出现该按钮。
2. 没装 Agent 时，图片仍可提取。
3. Check：真图跑完，`ocr.md` 含标记字，原件字节不变，不调 Agent。
4. Check：PDF 拒绝；低置信度行带「待确认」。
5. `--e2e`：无 CLI 门禁下走通，结果可拖出。
6. 确认条不写 Workspace / 不说已关沙箱。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设

- 本机 Vision 含 `zh-Hans` / `en-US`（已在本机测过）。
- 第一版只认 `ItemKind.image`，网站截图 part 不单独出按钮。
