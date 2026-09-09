# 参与 DropAgent

产品事实以 `01-requirements.md`、`02-prototype-design.md` 为准。模块边界见 `03-tech-architecture.md` 和 `design/modules/`。

## 环境

- macOS 14+
- Swift 6（Xcode 或 Command Line Tools）

## 检查

在 `macos/` 下：

```bash
swift run DropAgentCheck
swift build --product DropAgent
```

本机没装 Grok 时，live Grok 检查会跳过，其余仍应通过。抓页、真实终端会话依赖本机权限和已装 Agent，不作为默认门槛。

图形端到端（需要本机 GUI）：

```bash
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 改行为

会改变界面、Recipe 或数据规则时，先写或更新 `specs/<task>/spec.md`，再改代码。不要在 `prototype/index.html` 里发明内核没有的规则。

不要：覆盖用户原件、接云端 API、解析 TUI 画面、加载用户全局 MCP / Hooks。
