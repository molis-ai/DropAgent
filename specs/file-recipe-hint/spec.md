# generic file 全灰时说明下一步

## 背景目标

`01` 接收任意文件；`generic-file` 规定总结 / 抽取 / 翻译 / 脱敏 / 转 MD 不接 `.file`，「新交付」要两份。拖进 `archive.zip` 后六个按钮全灰，下面仍写「或在下面写一句话，发送到 Grok」。人会以为动作坏了，不知道 ZIP 只能发给终端，或再选一份做新交付。

## 当前行为与问题证据

预览 `18-file`：ZIP 选中，六个 Recipe 禁用，提示仍是给「能跑动作」的材料写的那句。`recipeHelp` 只在 hover / VoiceOver。Impeccable Operate：禁用控件要写清问题和恢复。

## 范围

- 有 Codex、当前选中没有任何 Recipe 能跑：动作区那句改成说明，不继续用「或在下面写一句话」。
- 其中含 `.file` 且还不够两份：写明这类文件不能总结或翻译；发给当前 TUI，或再选一份做「新交付」。
- 其他全灰：写明选中的材料不能跑这些动作，发给当前 TUI。
- 至少有一个 Recipe 能跑：仍用原来的「或在下面写一句话…」。
- 无执行入口 / 无 TUI：沿用门禁两句，不改。
- 预览 `18-file` 能读到新句；`03-idle`（PDF 能总结）仍是旧句。
- `--e2e` 验 ZIP 那句。不改 Recipe 接受表、不改四条调用链。

## 非目标

- Developer ID。
- 不把 ZIP 接到总结 / 翻译。
- 不藏起全灰的六个按钮。

## 使用场景

拖进报价 zip：看见「这类文件不能总结或翻译。发给 Grok，或再选一份做「新交付」。」于是发送或 Command 再点一份 PDF。

## 方案与关键决策

文案集中在 `AppSession.recipeChooserHint`。View 只转述。不按扩展名写 ZIP/DOCX。

## 输入输出与依赖

输入：`hasRecipe` / `hasAgent` / `recipeFitsSelection` / `recipeBatch`。输出：动作区提示一句。

## 文件 / 模块边界

- `macos/App/AppSession.swift`
- `macos/App/PanelRootView.swift`
- `macos/App/AppE2E.swift`
- 本 spec

## 验收标准

1. `--e2e`：有 Codex、架子上只有一份 `.file` 且选中 → hint 含「这类文件不能总结或翻译」和「整合」，不含「或在下面写一句话」。
2. `--e2e`：选中 PDF → hint 含「或在下面写一句话」。
3. 预览 `18-file` 能读到「这类文件不能总结」；`03-idle` 仍是「或在下面写一句话」。
4. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

无。
