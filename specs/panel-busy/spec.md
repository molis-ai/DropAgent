# 忙的时候别误发送；架子少留空档

## 背景目标

副本任务「等待授权 / 运行中」时，底下发送仍是系统蓝。人会以为那是去授权。确认 Recipe 时发送会把条目改成已进终端，等于跳过副本。一条文件时架子默认 188pt，下面空一截。

## 当前行为

- `发送` 只在没 Agent 或正在抓页时禁用。
- `listHeight` 默认 188，未拖过分隔条时一条待处理下面大块空白。

## 范围

- 选中项是 `confirm` 或 `running`：输入框和发送禁用；抓页中仍禁用。
- 占位字说明先取消或等任务结束，不假装能发给终端。
- 忙的时候脚注只留快捷键，不把「Codex 在副本里跑」再说一遍。
- 未拖过分隔条：空态架子 140pt；有条目时高度贴行（单行 56pt，上限 320）。已有 `panel.json` 仍按用户拖过的高度。
- 不改四条调用链。

## 非目标

- Developer ID。不把 Recipe 接到 Grok。

## 验收

1. 预览 `04-confirm`、`05-running`、`05b-waiting`：发送是暗的，不是系统蓝。
2. 预览 `03-idle`：一条 PDF 时架子贴着那一行，下面不再空一截纸。
3. 预览 `05-running`：脚注不再重复「Codex 在副本里跑」。
4. 空态、已完成、已进终端仍可发送（有 TUI 时）。
5. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
```
