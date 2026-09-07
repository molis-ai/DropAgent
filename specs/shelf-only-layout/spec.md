# 工作和结果可收起；轮盘可关

## 背景与目标

不是人人都装了本地 Agent。三栏全开时，只想把文件放在架子上的人面对一块约 800 宽的空纸。拖文件时的六瓣轮盘也不是人人要。

完成等级：功能可用。

## 当前行为

- 面板固定约 800：输入 | 工作 | 结果，不能收。
- 拖文件时轮盘总会出现（顶边标签栏、出圈、面板上除外）。
- 设置 → 外观只有颜色和语言。

## 范围

- 输入栏不能关。工作、结果各自显隐，写入 `prefs.json`，默认都开。列表和文件还在。
- 关一栏，面板跟着变窄，右缘仍贴菜单栏图标。只留架子时约 260–280，不是 800 空纸。
- 头上一个「栏」菜单，勾选工作 / 结果。设置 → 外观同一组开关。
- 外观增加「拖文件时显示轮盘」，默认开。关掉后不出六瓣；菜单栏图标、输入列表、工作栏（若开着）仍接拖。
- 动作跑完时若结果栏关着：自动打开结果栏。点一条结果要预览、工作栏关着：自动打开工作栏并切到预览。
- 打开设置或就绪卡时，窗口仍用满宽 800，避免设置被挤扁。

## 非目标

- 不因没装 Agent 自动收栏。
- 不把工作和结果绑成一个总开关。
- 不是关掉就只能去设置里找回来。
- 不改四条调用链、不覆盖原件、不加载全局 MCP。

## 方案

- `AppPreferences`：`showWork` / `showResult` / `showDropWheel`，`decodeIfPresent` 默认 `true`。
- `LivePanelChrome.fittedWidth`：三栏 800；只工作 = 800 − 结果宽 − 分隔；只结果 = 输入 + 分隔 + 结果；只架子 260–280。
- `AppDelegate.positionPanel` 用 `session.panelWidth`，不再写死 800 / 最小 360。
- `PanelRootView` 按开关组装栏；只留架子时输入列铺满。
- `EdgeDropController` 在 `showDropWheel == false` 时不 `showWheel`。
- `adoptNewestResult` 打开结果栏；`selectResult` 打开工作栏并 `aiTab = .result`。

## 验收

1. 空 `prefs.json` 解码后三开关均为 true。
2. `fittedWidth`：三栏 800；默认宽度下只工作 588、只结果 408、只架子在 260–280。
3. 关结果后视图树没有 `result-stack`；关工作后没有 `ai-pane`。
4. `selectResult` 会把 `showWork` 置 true。
5. `adoptNewestResult` 会把 `showResult` 置 true。
6. 设置外观英文能看到 `Show drop wheel`、`Work`、`Results`。
7. Check 全绿；`swift build --product DropAgent` 通过；`--e2e` 通过。

## 验证

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```
