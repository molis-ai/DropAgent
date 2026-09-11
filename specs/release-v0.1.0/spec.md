# DropAgent v0.1.0 首次 GitHub Release

## 目标与授权

用户要求在 GitHub 发布 v0.1 安装包，并介绍核心功能。目标仓库为 `molis-ai/DropAgent`，版本使用现有应用版本 `0.1.0`，标签 `v0.1.0`。本次授权包含将当前完成的功能提交到源码仓库、推送标签和公开发布 Release。

完成等级：发布物与本机安装路径验证；不是所有 Agent、系统版本与硬件组合均完成验收。

## 当前证据与范围

- 当前没有 Release/标签。远端仅比本地多一次验收日志清理，先快进纳入。
- 当前打包脚本只复制 debug 可执行文件。增加可选 release 配置；开发默认行为保持不变。
- 现有版本信息为 `0.1.0` / build `1`，macOS 14+。当前构建与验证机器为 arm64，本次明确发布 Apple Silicon 安装包。
- 没有 Developer ID 签名证书，使用现有 adhoc 签名，并说明未公证的安装路径；不冒充 Apple 已验证的应用。
- 包含当前已完成的首次示例、黑白界面、面板位置修复、文件/网页/剪贴板入口、本机 PDF/图片文字提取、Agent 动作和结果导出。介绍以源码实际行为为准。

## 方案、输入输出与边界

- 修改 `macos/package-app.sh`：读取 `DROPAGENT_CONFIGURATION`（默认 debug，可选 release），从 SwiftPM 返回的构建目录复制可执行文件；随 App 放入许可文件和实际依赖的 `SwiftTerm_SwiftTerm.bundle`。发布检查发现旧脚本漏带该终端渲染资源，需一起补齐，避免依赖构建机文件。
- 补全 SwiftTerm 的 MIT 许可原文到 NOTICE。发布 ZIP 只含正式 `DropAgent.app`，不包含 Review、测试数据、构建缓存或个人日志。
- 更新 README 的下载入口、安装说明，新增 `docs/releases/v0.1.0.md` 作为 GitHub Release 正文，新增最短安装说明和可复现发布命令。
- 提交当前版本源码，标签指向该提交；上传 `DropAgent-v0.1.0-macos-arm64.zip` 和 `SHA256SUMS.txt`。校验和仅用于发布产物下载完整性。
- 不改功能协议、不新增功能、不购买或配置证书、不接入自动更新；Intel 版本不在本次二进制发布范围。

## 验收与验证

- [x] release 构建成功，包内版本 0.1.0、正式 bundle ID、arm64、最低系统 macOS 14，链接仅指向系统依赖，许可与终端资源齐全。
- [x] `DropAgentCheck` 通过；从分发 ZIP 解压出的 App 运行 `--e2e --panel-only` 和 `--e2e --ui-only` 通过。
- [x] `codesign --verify --deep --strict`、压缩包解压检查、SHA256 校验通过。
- [x] README / Release 说明包含核心用途、最短体验、系统与 Agent 前提、权限与未公证说明。
- [x] GitHub 标签与发布源码一致，Release 可见，附件可下载，远端下载校验通过。

假设用户的“v0.1”采用标准标签 `v0.1.0`；未公证状态在发布页明确公开。

## 本地发布验证

```bash
DROPAGENT_CONFIGURATION=release bash macos/package-app.sh
swift run -c release --package-path macos DropAgentCheck
ditto -c -k --sequesterRsrc --keepParent macos/dist/DropAgent.app macos/dist/v0.1.0/DropAgent-v0.1.0-macos-arm64.zip
ditto -x -k macos/dist/v0.1.0/DropAgent-v0.1.0-macos-arm64.zip /tmp/dropagent-v0.1.0-install
codesign --verify --deep --strict /tmp/dropagent-v0.1.0-install/DropAgent.app
DROPAGENT_ROOT=/tmp/dropagent-v0.1.0-panel /tmp/dropagent-v0.1.0-install/DropAgent.app/Contents/MacOS/DropAgent --e2e --panel-only
DROPAGENT_ROOT=/tmp/dropagent-v0.1.0-ui /tmp/dropagent-v0.1.0-install/DropAgent.app/Contents/MacOS/DropAgent --e2e --ui-only
```

以上均通过。实际二进制的 LC_BUILD_VERSION 为 macOS 14.0；宿主验证环境为 Apple Silicon / macOS 26，未实测 macOS 14、Intel 和跨显示器。内核检查中的可选 live capture 返回 `captureFailed`，因此不把该项计为抓取成功；真实网页 URL 抓取通过，其余依赖权限的流程以发布说明中的边界为准。原始本机日志只保留在临时目录，不上传仓库。

## 已发布

- [v0.1.0 Release](https://github.com/molis-ai/DropAgent/releases/tag/v0.1.0) 于 2026-09-11 公开发布，标为 Latest，非草稿、非预发布。
- 标签对应源码提交 `c6d718dc9336afd780f3e3a52897a582fb510cec`；[该提交的 GitHub CI](https://github.com/molis-ai/DropAgent/actions/runs/34592393731) 通过。
- 附件为 `DropAgent-v0.1.0-macos-arm64.zip`（3,108,903 字节）与 `SHA256SUMS.txt`。已从 GitHub 重新下载，校验和通过且与本地已验证分发 ZIP 字节一致。
- 所有本次验收项通过；系统版本、Intel、真实抓取等未验证边界保持上述说明。
