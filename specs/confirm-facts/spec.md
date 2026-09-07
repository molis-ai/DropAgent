# 确认条的写和网络不要在没沙箱时夸口

## 背景目标

`01` 要求执行前写清写哪里、是否联网、哪一档隔离。`isolation-fact` 只改了「隔离」一行。Codex 探测不到工作区限制时，`execArguments` **不加** `--sandbox`。确认条却仍写「写：仅任务目录」「网络：关」。人会以为进程被关在任务目录且不能上网。

## 当前行为与问题证据

预览 `04b-unconfirmed`：隔离是「未确认工作区限制，仍在副本目录跑」，写仍是「仅任务目录」，网络仍是「关」。Check 已覆盖 translate 在 workspace 时带 `network_access=true`；面板未证实沙箱时仍按 recipe 的 开/关 说。

## 范围

- 能证明 workspace：写「仅任务目录」；网络按 Recipe（总结关、翻译开）。
- 不能证明：写「未确认仅任务目录」；网络「未确认」。不写关、不开。
- 读仍是副本（工作流承诺，与沙箱无关）。
- 预览 `04b-unconfirmed` 写/网络都是未确认。新增 `04c-translate`：workspace 时翻译显示网络开。
- `--e2e` 验这三档文案。
- 不改 `execArguments`、不改四条调用链。

## 非目标

- Developer ID。
- 不扩 `IsolationShown`。
- 不把「未确认」说成 Safe Copy。

## 使用场景

本机有 Codex 但 `--help` 证不了 workspace-write：点「总结」后，写和网络都是未确认，和隔离那句一致。本机能证明沙箱时点「翻译」，网络是开。

## 方案与关键决策

UI 只转述能否证明沙箱。没证明就不把 recipe 的「默认不联网」说成已经关掉。

## 输入输出与依赖

输入：`recipePresence.isolation`、当前确认的 Recipe。输出：权限条「写」「网络」。依赖现有 `CodexCLI.execArguments`。

## 文件 / 模块边界

- `macos/App/AppSession.swift`
- `macos/App/PanelRootView.swift`
- `macos/App/PanelPreview.swift`
- `macos/App/AppE2E.swift`
- 本 spec

## 验收标准

1. `--e2e`：unknown + 总结 → 写含「未确认」，网络是「未确认」，都不含单独的「关」当承诺。
2. `--e2e`：workspace + 总结 → 写「仅任务目录」，网络「关」。
3. `--e2e`：workspace + 翻译 → 网络「开」。
4. 预览 `04b-unconfirmed` 写/网络为未确认；`04c-translate` 网络为开。
5. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

无执行入口时确认条隔离已是「无执行入口」。写/网络同样写「无执行入口」。
