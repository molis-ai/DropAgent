# 第一次打开就见到架子；结果按 Markdown 看

## 背景目标

`LSUIElement` 启动后没有 Dock 图标。第一次双击 `DropAgent.app` 只出现菜单栏小图标，面板不出来，像没打开。结果页现在把总结当纯文本，列表和标题挤成一行。

## 当前行为

- 正式 App 启动不调用 `showPanel`，只注册状态项和热键。
- `--capture` / `--preview` / `--e2e` 各走自己的窗口，不经过这次「第一次打开」。
- `resultBody` 用 `Text(String)`，不解释 Markdown。

## 范围

- 普通启动且还没有打开过标记：启动后展开面板，再写下标记。之后**新进程**启动不再自动弹出。
- 进程已在跑时，再双击 `DropAgent.app` / `open -a DropAgent`：走 `applicationShouldHandleReopen`，展开面板。这不是冷启动，不改标记。`LSMultipleInstancesProhibited` 避免两个菜单栏图标。
- `--capture` / `--preview` / `--e2e` 不弹这块面板、不写标记、不处理 reopen。
- 结果是 `.md`：按 Markdown 显示（标题、列表、强调）；`.json` 仍用等宽纯文本。解析失败则退回纯文本。
- 不改四条调用链。

## 非目标

- 不做多页新手引导、示例 PDF、教练标记。
- Developer ID。

## 验收

1. 空的 `DROPAGENT_ROOT` 下普通启动会看到面板；同一 root 再启动（新进程）不自动弹出。
2. 已在跑时再次打开 App，面板会出来。
3. `--capture` / `--e2e` 不创建「已打开」标记、不弹这块面板。
4. 预览 `06-result` 仍能读到总结正文；带 `-` 列表的总结在结果 Tab 不再糊成一段。
5. Check 全绿。
6. `--e2e`：`FirstOpen` 只在非诊断且还没有标记时展开；过程中不得写出 `opened`。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
DROPAGENT_ROOT=/tmp/dropagent-first-open macos/.build/debug/DropAgent
```
