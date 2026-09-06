# DropAgent

产品事实以 `01-requirements.md`、`02-prototype-design.md` 为准。分包、调用链、禁区以 `03-tech-architecture.md` 和 `design/modules/` 为准。不要在 Adeptify 仓库里改这个产品。

## 栈

- macOS 14+，Swift 6，AppKit + SwiftUI
- 内核：`macos/Packages/`（无 UI，可单测）
- 壳：`macos/App`（菜单栏、面板、快捷键、PTY）
- 设计原型：`prototype/index.html`（禁止在原型发明内核没有的业务规则）

## 命令

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
bash macos/package-app.sh   # 装进 dist/DropAgent.app；有 Developer ID 就签，否则 adhoc
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/dist/DropAgent.app/Contents/MacOS/DropAgent --e2e
# Safari、Chrome 或 Edge 在最前时：
DROPAGENT_ROOT=/tmp/dropagent-capture-live macos/dist/DropAgent.app/Contents/MacOS/DropAgent --capture
```

## 禁区

- 禁止 Utils / Common / Helper 杂烩包；跨模块只走 public API；App 是唯一装配点
- 不加载用户全局 MCP / Hooks；Prompt 里不写原件路径
- 不自动覆盖用户原文件；复制不用符号链接
- 第一版不上 Mac App Store；不接云端 API / Ollama
- 不解析 TUI 画面、不模拟键盘去点终端菜单
