# 选文件窗不能被 DropAgent 挡住

## 背景与目标

点 + 或设置里选文件夹时，系统文件选择窗出现在 DropAgent 下面。面板是 `.statusBar` 层，比 `NSOpenPanel` 高。

## 范围

- `pickFilesToAdmit`、`pickWorkspaceFolder`、`pickTUIExecutable` 弹出选文件时，把本 App 的 statusBar 窗口临时降到普通层；关掉选择窗后恢复。
- 不改四条调用链，不改投放条几何。

## 验收

1. 点 + 弹出的 Finder 选择窗在 DropAgent 前面，可以点到。
2. 选完或取消后，面板仍挂在菜单栏层。
3. Check 全绿；e2e 通过。
