# 结果页的网址要点得开，Markdown 链接也一样

## 背景目标

`02`：点开网站条能看链接；URL 条显示地址。URL 结果页已经用冰蓝色画地址，看起来能点，`urlMaterials` 却只是 `Text`。网站条的地址还是灰色。抓页正文里的 `[字](url)` 在结果页同样点不开。人会以为坏了。

## 当前行为与问题证据

预览 `16b-url-result`：冰蓝色 `https://dropoverapp.com`，无按钮、无 `openURL`。`07b-web-result` 的地址是 11pt `muted`。`inlineMarkdown` 会把链接做成 AttributedString，但结果区没有处理打开。

## 范围

- `http` / `https`：网站、URL 的动作 peek 和结果页可点，用系统浏览器打开。
- 颜色用已有的 `Palette.ice`，不用系统蓝（`02` 系统蓝只给发送、选中、投放）。
- 结果 Markdown 里的链接同样只打开 `http` / `https`。
- `file:`、`javascript:` 不打开。
- `--e2e` 验 `SourceLink.isOpenable`，不真开浏览器。
- 不改四条调用链，不自动抓正文。

## 非目标

- Developer ID。
- 不在面板里内嵌浏览器。
- 不改拖出形态。

## 使用场景

架子上有一条 `https://dropoverapp.com`。点「结果」再点地址，用默认浏览器打开。⌃⌥W 抓到的页，点正文里的链接也是打开浏览器，不是假装导航。

## 方案与关键决策

打开只走 `NSWorkspace`。判定集中在 App 的 `SourceLink`，View 不自己写 scheme。

## 输入输出与依赖

输入：Item.`sourceURL` 或 Markdown 链接。输出：系统打开 URL。依赖现有结果 Tab。

## 文件 / 模块边界

- `macos/App/SourceLink.swift`
- `macos/App/PanelRootView.swift`
- `macos/App/AppSession.swift`（若打开从 session 走）
- `macos/App/AppE2E.swift`
- 本 spec

## 验收标准

1. `--e2e`：`https` / `http` 可打开；`file:` 与 `javascript:` 不可。
2. 预览 `16b-url-result` 仍能读到 `https://`；`07b-web-result` 地址是冰蓝色。
3. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

预览不能代点击。打开行为由 `isOpenable` + 代码路径证明。
