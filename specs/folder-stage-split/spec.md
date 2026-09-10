# 文件夹内容台：左目录树，右文件预览

## 背景与目标

复制进来的 DIR 在内容台里只列十来个文件名，看不清结构，也点不开里面的文件。点开文件夹后，左边走目录树，右边预览当前选中的那份文件。

完成等级：功能可用。

## 当前行为

- `ResultPreview` 对 folder 只列出副本根下最多 12 个名字。
- 内容台对文件夹整份只读，不能编里面的文件。

## 范围

- 内容台遇到 `kind == folder`：左侧目录树（Inbox 副本），右侧预览选中文件。
- 点目录展开/收起并选中；点文件在右侧预览（图、文稿、代码走现有 `ResultPreview`；PDF / 二进制仍提示拖出）。
- 默认选中根下第一份文件；没有文件则右侧说明这是文件夹。
- 只读副本。不跟到副本外的符号链接。不显示点文件。单层最多 200 项。
- 悬停卡、结果区浮窗仍用原来的短列表。

## 非目标

- 不在树里改文件、不拖出单个子文件、不把文件夹内容台变成编辑器。
- 不预览 node_modules 级的整棵巨树（超限截断即可）。

## 方案

- 内核 `DropAgentIngest.FolderListing`：列出某目录下合法子项、找第一份文件。
- App `FolderStage`：左树右预览，接到 `ContentStage`。

## 验收

1. 选中带 `notes.md` 的文件夹：左边能看见目录和 `notes.md`，右边是文稿预览。
2. 点另一个文件，右侧换成那份；原件不被写入。
3. 空文件夹、打不开、越出副本的链接：树空或跳过，不崩。
4. `swift run DropAgentCheck` 与 `--e2e` 通过。

## 验证

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```
