# 按开源项目标准公开

## 背景与目标

仓库能打包试用，但还不能当开源项目公开：没有许可证、GitHub 仍是私有、README 截图还是旧三栏。补齐外人能看懂、能编译、能判断怎么用的最小公开面，再把仓库改成 public。

## 当前行为与问题证据

- `molis-ai/DropAgent` 为 private，不允许 fork。
- 无 `LICENSE`。依赖 SwiftTerm（MIT）未声明。
- README 首图仍是左输入 / 中动作 / 右结果。
- 第一次成功路径写成「选总结」，没装 CLI 的人会卡住。
- 无 CI、无贡献说明、无漏洞反馈入口。
- `docs/验收/` 是内部验收，截图过期。
- `DropAgentCheck` 在本机没装 Grok 时会 fail `liveGrok`。

## 范围

- MIT 许可证 + SwiftTerm NOTICE。
- README 换成当前界面（上文件、中内容台、下结果区），上手改为不依赖 Agent 的「文字提取」。
- 用 `--preview` 现拍静帧替换过期截图；拿掉旧三栏 GIF。
- GitHub Actions 跑 `swift run DropAgentCheck`。
- CONTRIBUTING、SECURITY。
- `docs/验收` 标明内部历史，不删记录。
- Check：没装 Grok 时跳过 live Grok，不 fail。
- 提交后把仓库改为 public，并允许 fork。

## 非目标

- 不改 Bundle ID、不公证、不发 GitHub Release / dmg。
- 不把 OCR 做成主产品。
- 不重写 120 份 spec。
- 不把 `.impeccable/` 纳入 git。

## 验收标准

1. 根目录有 MIT `LICENSE`；README 写明许可并链到它。
2. README 截图是当前上下架布局，不是三栏。
3. 上手路径不要求已装 CLI Agent。
4. `.github/workflows/check.yml` 在 macos runner 上跑 DropAgentCheck。
5. 无 Grok 时 `swift run DropAgentCheck` 仍可通过（跳过 live Grok）。
6. 仓库 public，允许 fork。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
gh repo view molis-ai/DropAgent --json isPrivate,url
```
