# 副本任务运行时写明是 Codex

## 背景目标

头上芯片是当前 TUI（本机常是 Grok）。点「在副本中运行」后，动作区只写「运行中 / 工具调用」，人会以为是 Grok 在跑。Recipe 第一版只保证 Codex `exec`。

## 当前行为与问题证据

预览 `05-running` / `05b-waiting`：芯片「Grok」，动作区没有 Codex / 副本字样。`01-requirements.md` 要求执行前和执行中能看懂谁在跑。

## 范围

- 选中项 `confirm`：权限四行仍是读 / 写 / 网络 / 隔离；其下用 Codex 执行者一句，不再重复贴隔离档全文。
- 选中项 `running`：动作区除事件外，同一句写明这是 Codex 副本任务，不是当前 TUI。
- 确认中 / 运行中：页脚第一行改成这句，不继续写「发送进当前 TUI」。
- 不改 Job / TUI / 芯片。发送在 running / confirm 时仍禁用（`panel-busy`）。
- 抓页失败仍独占动作区（`capture-progress`）。

## 非目标

- 不把 Recipe 接到 Grok。
- Developer ID。

## 方案

文案集中在 `HotKeyCopy.recipeActorLine`。确认态、运行态、这两种页脚共用。预览 `04-confirm`、`05-running`、`05b-waiting` 能读到这行。

## 验收

1. 预览确认、运行中、等授权：能读到 Codex 与副本，且不把当前 TUI 说成执行者。
2. 预览确认：权限条仍有隔离档；不再在按钮上方重复整段隔离说明。
3. Check 全绿；四条调用链不变。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
```
