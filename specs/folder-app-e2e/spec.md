# App 端到端：文件夹和其他文件也能拖出

## 背景目标

`01` 接收文件夹和任意文件。`03` §9.8：网站组合拖出文件夹已经在 App e2e 走通；DIR 条和 ZIP 只在 Check 里落地。人不准用真 Codex。壳上 `admit` → 拖出，对材料夹和认不出的文件没有证据。

## 当前行为与问题证据

`--e2e` 拖出过 PDF、`summary.md`、`extracted.json`、`brief.md`、网站标题目录。没有进过一个文件夹，也没有进过 `.zip`。

## 范围

- `--e2e`：进一个带 `notes.md` 的文件夹 → 条目标签 DIR → 拖到桌面仍是目录，里面有 `notes.md`；原文件夹内容不变。
- `--e2e`：进 `archive.zip` → 标签 ZIP、类型「文件」；总结不合规；拖出落地文件名是 `archive.zip`；原件 Hash 不变。
- 测完删条，后面抓页 / Grok 仍过。
- 不改四条调用链。

## 非目标

- Developer ID。
- 不解析 zip 内部。
- 不把 Recipe 接到 Grok。

## 使用场景

拖进一个材料夹，先不跑，再拖到桌面：打开能看到原来的文件。拖进压缩包：不当成文稿，发给终端或拖走。

## 方案与关键决策

走现有 `admit(urls:)` 和 `PasteboardService.itemProvider`，与面板拖出同一条 API。

## 输入输出与依赖

输入：测试目录、测试 zip。输出：桌面落地目录/文件、原件 Hash。

## 文件 / 模块边界

- `macos/App/AppE2E.swift`
- 本 spec

## 验收标准

1. `--e2e`：落地物是目录，内有 `notes.md`；原目录里的 `notes.md` 正文不变。
2. `--e2e`：ZIP 条 `displayTag` 为 `ZIP`；`recipeFitsSelection(.summarize)` 为假；落地 `archive.zip`；原件 Hash 不变。
3. `--e2e`：随后抓页、Grok 发送仍过。
4. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

顶边真人从 Finder 拖仍要亲手走一次。
