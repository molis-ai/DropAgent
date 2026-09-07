# 空架子时动作区不要说「点列表」

## 背景目标

空面板上半已经写「拖到这里」。下半动作区仍用「点列表里的文件」，架子是空的，这句话没有对象，空态读起来像说明书叠说明书。

## 当前行为与问题证据

预览 `01-empty`：架子空，动作区 `HotKeyCopy.workIdleHint` 仍是「点列表里的文件，或拖到上方加入、拖到这一区发给 Grok。」原型同一句。

## 范围

- `workIdleHint` 增加 `hasItems`。有条目时保留「点列表里的文件」。
- 无条目且有 TUI 和 Codex：改成「拖到上方加入架子，或拖到这一区发给 {TUI}。」
- 无 TUI / 无执行入口的现有句按 `recipe-follows-chip` 走，不在本项发明第三套。
- 原型空动作区跟正式 App 同一套。
- 不改四条调用链、不改空架子主文案、不改脚注隔离说明。

## 非目标

- Developer ID。
- 不重做 Recipe 宫格。
- 不激活用户主 Chrome。

## 使用场景

第一次打开空面板：上半告诉人怎么放进来，下半告诉人拖到 AI 区会发给当前 TUI，不假装已经有列表。

## 方案与关键决策

空态两区分工：上加入，下发给。有条目才提「点列表」。

## 输入输出与依赖

输入：是否有架子条目、是否有 TUI/Codex。输出：动作区空闲提示一句。

## 文件 / 模块边界

- `macos/App/HotKeyCenter.swift`
- `macos/App/PanelRootView.swift`
- `macos/App/AppE2E.swift`
- `prototype/index.html`
- 本 spec

## 验收标准

1. 预览 `01-empty` 动作区不含「点列表」；含「加入架子」和「发给 Grok」。
2. `--e2e`：`hasItems: false` 不含「点列表」；`hasItems: true` 仍含「点列表里的文件」。
3. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

无。
