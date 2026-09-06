# 面板改成北欧纸面：黑白、用图标

## 背景目标

一骏要北欧现代，但不要松绿点缀；尽量黑白，动作用合适图标。产品机制不变：400pt 一列、上架子下 AI、四条调用链。文件种类仍用标签字，不用文件图形图标。

## 当前行为与问题证据

上一刀曾把强调色改成松绿。纠正：强调只用墨色；状态不用绿/红/蓝点。

## 范围

- 浅纸底、墨色字。发送 / 选中 / 投放用黑，不用彩色强调。
- 失败、运行中、已连接：靠字重、灰阶和图标，不用语义彩点。
- 脚注、占位、次要说明在纸面 `#f7f7f5` 上对比度至少 4.5:1。`faint` 用 `#6e6e6e`，不再用 `#787878`（约 4.1:1）。作曲家占位跟 Palette，不写死 120。
- SF Symbols 一律单色渲染，不走系统绿勾 / 红斜杠 / 蓝波纹。
- 终端井近黑。打开中、空态也是同一口井，不用白纸挡住。
- 动作（发送、粘贴、复制、拖出、Recipe、终端、关闭、空态）用 SF Symbols。
- 原型与正式 App 同一套黑白纸面。
- `02` 视觉原则、`DESIGN.md` 跟着改。
- 不改四条调用链。

## 非目标

- Developer ID。
- 不为 detector 改 `PRODUCT.md` 的 `platform: web`。
- 不把文件 kind 换成图形图标。

## 使用场景

夜里点开菜单栏，看到一张浅色纸。发给 Grok 是纸飞机，粘贴是剪贴板，不是一排灰按钮。

## 方案与关键决策

夜桌仍深；面板是白纸。唯一强调是黑。用户明确否决松绿。

## 文件 / 模块边界

- `macos/App/Palette.swift`、`PanelRootView.swift`、`AppDelegate.swift`、`AppE2E.swift`、`PanelPreview.swift`
- `prototype/index.html`
- `02-prototype-design.md`、`DESIGN.md`
- 本 spec

## 验收标准

1. 预览 `01-empty` / `03-idle` / `06-result`：浅底深字，发送/拖出是黑底白字，没有绿/蓝强调。
2. 头上状态、Recipe、粘贴/发送能看见对应 SF Symbol；`checkmark.circle.fill` / `circle.slash` 是墨色，不是系统绿/红。
3. Check 全绿；`--e2e` Grok 发送仍过；recipe / confirm-run identifier 仍在。
4. 预览 `01-empty` 脚注和输入占位仍可读；ComposerField 占位色来自 Palette.faint。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```
