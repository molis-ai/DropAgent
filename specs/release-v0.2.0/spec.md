# DropAgent v0.2.0 GitHub Release

## 背景目标

用户要求提交当前工作台改动、推送到 `molis-ai/DropAgent`，并发布安装包。相对已公开的 v0.1.0，源码已换成左目录右预览的文件工作台，并打磨投放、侧栏、预览按钮、确认/整合和轮盘摩擦。版本号 `0.2.0`，标签 `v0.2.0`。Release 介绍讲清这些近期提交的功能，而不是重复 v0.1.0 的首次产品说明。

完成等级：5（可发布安装包与 GitHub Release）。未实测 Intel、macOS 14 真机、Developer ID / 公证。

## 当前行为与问题证据

- 远端 Latest 仍是 [v0.1.0](https://github.com/molis-ai/DropAgent/releases/tag/v0.1.0)；README 仍指向该包，并写明截图来自未发布的工作台。
- `main` 已有 `d0c0bea`（线性工作台），本机还有未提交的投放进货、侧栏、预览文字按钮、确认/整合/轮盘修复。
- `CFBundleShortVersionString` 仍是 `0.1.0` / build `1`。

## 范围与非目标

范围：提交工作台改动；把版本改为 0.2.0 / build 2；更新 README 下载入口；写 `docs/releases/v0.2.0.md`；release 构建、zip、校验和；推送 `main` 与标签；公开发布 GitHub Release（非草稿、非预发布）。

非目标：不买证书、不公证、不发布 Intel 包、不接自动更新、不改业务协议。

## 方案与关键决策

1. 产品改动单独提交；版本、README、Release 正文再提交一次，标签打在含 `0.2.0` 的提交上。
2. 沿用 v0.1.0 打包路径：`DROPAGENT_CONFIGURATION=release bash macos/package-app.sh`，adhoc 签名，附件 `DropAgent-v0.2.0-macos-arm64.zip` + `SHA256SUMS.txt`。
3. 介绍按「相对 v0.1.0 多了什么」写：工作台布局、整块面板投放、侧栏与搜索、对照/编辑副本、整合正文护栏、复制文件进架子。安装与未公证说明沿用 v0.1.0。

## 文件 / 模块边界

- `macos/App/Info.plist`
- `README.md`
- `docs/releases/v0.2.0.md`
- 本 spec
- 不把 `macos/dist/` 纳入 git

## 验收标准

1. 产品提交与 v0.2.0 提交均在 `origin/main`。
2. 分发 App 的版本为 0.2.0，bundle ID `local.dropagent`，arm64，最低 macOS 14。
3. `DropAgentCheck`（release）通过；从 ZIP 解出的 App 通过 `--e2e --workbench-only` 与 `--e2e --wheel-only`。
4. `codesign --verify --deep --strict` 通过；GitHub 附件可下载，SHA256 与本地一致。
5. Release 正文能让没跟过提交的人看懂：新工作台、投放、侧栏、编辑/对照、整合不再交差。

## 验证

```bash
DROPAGENT_CONFIGURATION=release bash macos/package-app.sh
swift run -c release --package-path macos DropAgentCheck
ditto -c -k --sequesterRsrc --keepParent macos/dist/DropAgent.app macos/dist/v0.2.0/DropAgent-v0.2.0-macos-arm64.zip
ditto -x -k macos/dist/v0.2.0/DropAgent-v0.2.0-macos-arm64.zip /tmp/dropagent-v0.2.0-install
codesign --verify --deep --strict /tmp/dropagent-v0.2.0-install/DropAgent.app
DROPAGENT_ROOT=/tmp/dropagent-v0.2.0-workbench /tmp/dropagent-v0.2.0-install/DropAgent.app/Contents/MacOS/DropAgent --e2e --workbench-only
DROPAGENT_ROOT=/tmp/dropagent-v0.2.0-wheel /tmp/dropagent-v0.2.0-install/DropAgent.app/Contents/MacOS/DropAgent --e2e --wheel-only
```

## 假设与开放问题

仍无 Developer ID；安装路径继续说明未公证。Intel 不在本次二进制范围。
