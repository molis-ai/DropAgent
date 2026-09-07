# 面板改成左右分栏：左架子、右 TUI；最小化；多选入口

## 背景目标

一骏要把菜单栏面板从「上文件 / 下 AI」改成左右并排：左文件、右 TUI。400pt 一列太窄，并排时要把纸面加宽，但仍是从菜单栏落下的纸，不是工作台。同一刀补右上角最小化，以及文件列表里看得见的多选入口。

## 当前行为与问题证据

- `PanelRootView` 是竖向：头、列表高度 `displayListHeight`、7pt 上下分隔条、AI 区。窗口 `400×620`。
- 关闭走 `hidePanel()`。没有最小化。没有系统标题栏。
- Command 点多选已经接通：`ClickModifiers` 在 `leftMouseDown` 记下 ⌘，`ItemRowView.onTapGesture` → `toggleSelect(id:command:)`。用户发现不了：唯一文案是动作区脚注「Command 点可选多项。」，列表上没有入口，也没有行前勾选。

## 范围

- 面板 **680×620**。头 44pt 通栏，字标仍居中。
- 左架子默认 **240pt**，可拖 **200–320pt**；右 AI 占满剩余。竖分隔 7pt，拖的是左右，不是上下。`panel.json` 存 `shelfWidth`，写法同旧 `listHeight`。旧 `listHeight` 忽略。
- 切到「终端」不再压缩架子。两侧始终并排。
- 投放：左列表 = `admit`；右 AI = `admit` 后 `TUI.send`。
- 关闭左边加最小化（SF Symbol `minus`）。点了 = `hidePanel()`，和点菜单栏图标同类。不要系统 `miniaturize`，不要红绿灯。
- 列表有条目时，栏顶有「多选」。进入后行前圆圈勾选，点行即加减选择（与 Command 点同一条 `toggleSelect(..., command: true)`）。退出写「完成」。Command 点仍可用。
- 北欧纸面、黑白、字标居中、字母标签、无彩色强调、无文件图形图标。
- `01` / `02` / `03` / `DESIGN.md` / `app-shell` / `ai-pane` 布局表跟上。不改四条调用链。

## 非目标

- 不改 Recipe / TUI / 进货规则。
- 不要 Shift 连续选。
- 不要系统标题栏、不要真窗口最小化。
- 不 commit / push。
- 不为 detector 单独改无关文案。

## 使用场景

点菜单栏：一张约 680pt 的纸落下。左边是架子，点「多选」勾两份 PDF；右边选「新交付」或发给 Grok。拖分隔条把终端井拉宽。点最小化，面板收起，再点图标回来。

## 方案与关键决策

400pt 并排两边都没法用。680 / 240 仍像菜单栏纸面：左栏够标签+文件名，右栏够三列 Recipe 和作曲家。最小化不是关 App，只是藏面板。多选是发现性，不是修坏掉的 Command 点。

## 输入输出与依赖

输入：现有 `listHeight` 手势、`hidePanel`、`toggleSelect`。输出：`shelfWidth`、左右分栏、最小化、列表「多选」。依赖现有四条调用链。

## 文件 / 模块边界

- `macos/App/PanelRootView.swift`、`AppSession.swift`、`AppDelegate.swift`、`PanelPreview.swift`、`AppE2E.swift`、`HotKeyCenter.swift`
- `prototype/index.html`
- `01-requirements.md`、`02-prototype-design.md`、`03-tech-architecture.md`、`DESIGN.md`、`PRODUCT.md`
- `design/modules/app-shell.md`、`design/modules/ai-pane.md`
- 本 spec

## 验收标准

1. 预览 `01-empty`：约 680pt 宽，左空架子、右动作区；头上字标居中；芯片右侧有最小化与关闭；无红绿灯。
2. 预览 `03-idle` / `13-multi`：左文件右 TUI；`13-multi` 看得到「多选」和行前勾选。
3. 分隔条左右拖，范围 200–320；`panel.json` 写 `shelfWidth`。
4. 最小化与关闭都 `hidePanel`，`LivePanelChrome` 仍 borderless、不含 titled / miniaturizable。
5. Command 点仍加减选择且不切 Tab。多选模式点行走同一条 command 选择。
6. Check 全绿；相关 e2e 断言跟上。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

无。最小化与关闭同为藏面板，不另做退出。
