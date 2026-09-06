# Grok 隔离 home 不要每次都当成第一次打开

## 背景目标

发给 Grok 后，内嵌终端要马上能用。`--e2e` 的 `e2e-tty.png` 停在隐私「Opt in / Opt out」，提示符是空的。用户那句已经作为启动参数传进去了，但画面被首次确认挡住。

## 当前行为与问题证据

- `IsolatedGrokHome.prepare` 每次发送都把隔离 `config.toml` 写成只有一句注释。
- 用户本机 `~/.grok/config.toml` 已有 `[privacy] privacy_banner_acked`，同时还有 `mcp_servers` 和 `permission_mode = "always-approve"`。
- 隔离目录只拷 `auth.json`，不拷隐私确认；下一次发送还会把 Grok 自己写进隔离 home 的确认再覆盖掉。
- 禁止解析 TUI 画面、禁止替用户点 Opt in。

## 范围

- 隔离 `GROK_HOME` 仍不加载用户 MCP / Hooks / plugins。
- 不把用户的 `always-approve` / `yolo` / `mcp_servers` 拷进隔离配置。
- 首次创建隔离 `config.toml` 时：若用户配置里有 `privacy_banner_acked` 这一行，只抄这一行进 `[privacy]`。
- 隔离 `config.toml` 已经存在时不要覆盖（Grok 自己写的确认要留下）。
- `auth.json` 仍每次拷。
- 不改四条调用链；不模拟按键。

## 非目标

- Developer ID。
- 不把 Recipe 接到 Grok。
- 不拷用户主题、模型默认值、permission_mode。

## 使用场景

1. 本机 Grok 已经点过隐私确认：第一次发给 DropAgent 里的 Grok，不再先挡一块 Opt in。
2. 同一 `DROPAGENT_ROOT` 里第二次发送：隔离配置还在，不会被写成空文件。
3. 用户从没点过确认：隔离 home 仍会看到 Grok 自己的确认，人在终端里自己点。

## 方案与关键决策

种子文件只含注释和可选的 `[privacy]`。用行匹配抄 `privacy_banner_acked`，不引入 TOML 库，也不整文件复制用户配置。

## 输入输出与依赖

- 输入：用户 `~/.grok/config.toml`（或 `GROK_HOME`）、隔离目录。
- 输出：隔离 `config.toml`、`auth.json`。
- 依赖：本机已登录的 Grok。

## 文件 / 模块边界

- `DropAgentTUI` 的 `IsolatedGrokHome`。
- Check 覆盖种子内容和「第二次 prepare 不覆盖」。
- `design/modules/tui.md`、`specs/multi-tui/spec.md` 同步这一句。

## 验收标准

1. Check：用户配置含 `privacy_banner_acked`、`mcp_servers`、`always-approve` 时，隔离配置有确认行，没有 MCP，没有 `always-approve`。
2. Check：隔离配置已存在时再 `prepare`，原文件内容仍在。
3. Check 全绿。`--e2e` 的终端井不再以隐私 Opt in 当主画面（本机已确认过的前提下）。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```
