# 字标居中；诊断窗不要标题栏红绿灯

## 背景目标

正式面板从菜单栏展开，无标题栏。`--preview` / `--e2e` 用了 `titled + fullSizeContentView`，红绿灯压在左对齐的「DropAgent」上。一骏要字标居中，默认就是工具栏展开，后续忽略 Developer ID。

## 当前行为与问题证据

本机截图：交通灯和衬线「DropAgent」叠在一起。`PanelPreview` / `AppE2E` 窗口 `styleMask: [.titled, .closable, .fullSizeContentView]`。`PanelRootView` 头是左字标、右芯片。

## 范围

- 头上「DropAgent」在 400pt 里水平居中；芯片和关闭仍靠右。
- `--preview` / `--e2e` 窗口改用与正式面板相同的 `LivePanelChrome`（borderless），不再画系统标题栏。
- 正式 App 仍从菜单栏图标落下展开；第一次打开逻辑不改。
- 原型 `.head` 字标同样居中。
- `DESIGN.md` 头布局跟上。
- 不改四条调用链。后续不再把 Developer ID 当完成门槛。

## 非目标

- 不改隔离文案、Recipe、抓页。
- 不为 detector 改 `PRODUCT.md`。

## 使用场景

点菜单栏图标：纸面从图标落下，字标在顶栏正中，右边是 Grok 芯片。预览窗不再长出红绿灯。

## 方案与关键决策

字标用 ZStack 居中，不靠左 padding 躲红绿灯。诊断窗直接去掉标题栏，和工具栏面板同一套铬。

## 输入输出与依赖

输入：400pt 头、正式 `LivePanelChrome`。输出：居中字标、无标题栏的预览/e2e 窗。

## 文件 / 模块边界

- `macos/App/PanelRootView.swift`
- `macos/App/PanelPreview.swift`
- `macos/App/AppE2E.swift`
- `prototype/index.html`
- `DESIGN.md`
- 本 spec

## 验收标准

1. 预览 `01-empty`：字标在顶栏中部，芯片靠右；窗上没有红绿灯。
2. `--e2e`：e2e 窗 `styleMask` 含 borderless、不含 titled；`LivePanelChrome` 仍无 titled。
3. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

Developer ID 按一骏 2026-09-06 口头确认忽略，不再阻塞完成。
