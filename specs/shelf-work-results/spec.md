# 三栏架子：选项进 Prompt，其他展开输入

## 背景与目标

原型已对齐：左输入 / 中工作 / 右结果；Recipe 确认带选项并写进命令；「其他」和六个动作排在一起，点了才展开底下输入框（不是弹窗）；文件类型标签带安静的色。把这些做到 Swift App。完成等级：功能可用（主链路真实工作，内部可试用）。

## 当前行为与问题证据

- 面板仍是 680 两栏：左架子 + 中 AI。结果叠在工作区中部 `ResultStack`（高 108）。
- `RecipeCatalog` Prompt 写死（翻译永远「翻译成中文」），确认页没有选项。
- 作曲家输入框常驻。没有「其他」。
- 文件标签一律灰底。字标是居中衬线。

## 范围

- 面板约 800。左输入（默认 196，176–240）、中工作、右结果（默认 196，168–240）。中间预览 tab 看产出正文；拖出 / 复制钉在右列底。
- Job 成功仍只 `addResult`，输入行回 idle，不把结果自动插回左列。结果行可拖出；拖到左列走进货复制，当成新材料。
- 六个 Recipe 确认页有选项，默认写进 `prompt.txt`：翻译（目标语言，源语言自动识别，默认中文）、抽取、总结篇幅、脱敏范围、转 MD 版式、新交付篇幅。
- 「其他」是第七个命令。底下输入框默认收着；点「其他」在原地展开。终端 tab 仍显示输入。不是弹窗。
- 文件类型标签带灰尘色。字标左对齐、10pt 字距。冷灰绿纸面。不改四条调用链，不覆盖原件，Prompt 不写原件路径。

## 非目标

- 不开放任意自然语言条件。
- 不为选项改产出文件名（抽取一律 `extracted.json`）。
- 不把 SwiftUI 做成 HTML 像素副本；气质对齐即可。
- 不改 Capture / 不加载全局 MCP。

## 方案

- `RecipeCatalog.choices(for:)` + `prompt(for:choiceID:)`。`Job.start(..., optionID:)` 默认用该 Recipe 的默认选项。
- AppSession 记 `recipeOptions`、`otherOpen`、`resultWidth`。
- `PanelRootView` 三栏。`ResultStack` 升为右列。

## 验收

1. Check：`Job.start` 翻译默认 Prompt 含「中文」和「自动识别」；选项 `en` 含 English；总结 `outline` 含「提纲」；Prompt 仍不含原件路径。
2. Check：总结跑完左列仍是原 PDF idle，右栏有 `summary.md`。
3. `--preview` / 面板：约 800 宽；右列是结果；点翻译有语言选项，默认中文。
4. 点「其他」展开输入框，无弹窗；再点可收起。
5. 结果行可 `onDrag`；拖到左列走 `admitDrop`（复制进货）。
6. PDF / 图 / 链接标签颜色不同。
7. `cd macos && swift run DropAgentCheck` 全绿；`swift build --product DropAgent` 通过。
8. `--e2e` recipe 环仍过（默认选项，不点芯片也能跑总结）。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 允许修改

- `macos/Packages/DropAgentJob/`、`macos/App/`、`macos/Check/main.swift`
- `design/modules/job.md`、`02-prototype-design.md`、`DESIGN.md`
- 本 spec
