# 安全反馈

DropAgent 在本机复制用户文件、读剪贴板、并可申请辅助功能 / 自动化 / 屏幕截图，以便把材料放上架子。请不要把真实密钥或私人文件贴进 Issue。

## 报告漏洞

请用 GitHub 的 [Security Advisories](https://github.com/molis-ai/DropAgent/security/advisories/new) 私下说明：

- 影响哪个版本（commit 或 `CFBundleShortVersionString`）
- 怎么复现
- 实际读到或写到了什么

不要在公开 Issue 里贴可利用细节。

## 范围

在范围内：未授权读到原件路径之外的用户文件、把材料发到非本机进程、签名绕过。

不在范围内：用户自己把文件拖给已装的终端 Agent 之后，该 Agent 按自己的权限做事。发给终端时界面会写明「不是副本沙箱」。
