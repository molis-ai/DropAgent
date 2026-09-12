# 验证记录 · 2026-09-12

完成等级：功能可用。原生工作台与轮盘已打包；尚未宣称可发布。

| 验收 | 结果与证据 |
| --- | --- |
| 编译与打包 | 通过。`bash macos/package-app.sh` 构建并生成 `macos/dist/DropAgent.app`，adhoc 签名；日志 `/tmp/dropagent-linear-package-final.log`。 |
| 内核回归 | `swift run DropAgentCheck` 全部通过；日志 `/tmp/dropagent-linear-check.log`。最终视觉校准后未重复无关内核测试。 |
| 原有 App 回归 | `--e2e --ui-only` 通过首次使用、权限恢复、设置、编辑、动作、失败恢复、PDF、OCR、导出；日志 `/tmp/dropagent-linear-final-ui.log`。 |
| 工作台闭环 | 对实际打包 App 运行 `--e2e --workbench-only` 通过。真实示例 PDF 提取文字、原件不变、结果复制与重新入架；日志 `/tmp/dropagent-linear-shipping-e2e.log`。 |
| 焦点与选择 | 重复点选不清空预览；剪贴板选择不写系统剪贴板/不上架/不误跑后台材料；方向键、删除、缺失文件、多条部分成功提示；多来源与缺失来源对照、删除结果、任务完成不抢剪贴板焦点均通过。 |
| 对话 | 收起/设置切换后同一个原生终端实例仍存在；紧凑窗口下输入、发送与边界说明截图可见。未在本次工作台 E2E 发送真实外部 Agent 请求。 |
| 轮盘 | 既有 `WheelE2E` 通过连续拖入、临时空拖板、AppKit 接受、持久化副本、面板边界与取消。六个动作与命中几何不变。 |
| 视觉 | 查看浅/深主题材料、结果、对照、剪贴板、文件夹、确认、运行、失败、对话、800pt 英文窄窗口及轮盘。截图在 `/tmp/dropagent-linear-shipping/ui/`；README 使用其中三张原生截图，另保存浅色材料截图。 |

## 实际缺口

PDF 的真实文字提取与原生无障碍树读取通过；`PDFView` 页面图层未出现在 App 的位图快照中，独立 Review 窗口的屏幕截图工具持续超时。因此 PDF 页面实际屏幕显示仍待人工确认，不把无障碍文本或提取成功当作视觉通过。未做外部目标应用拖放联调或发布验证。

## 复现

```bash
cd macos
swift build --product DropAgent
swift run DropAgentCheck
cd ..
bash macos/package-app.sh
DROPAGENT_ROOT=/tmp/dropagent-workbench-verify macos/dist/DropAgent.app/Contents/MacOS/DropAgent --e2e --workbench-only
DROPAGENT_ROOT=/tmp/dropagent-ui-verify macos/dist/DropAgent.app/Contents/MacOS/DropAgent --e2e --ui-only
```

E2E 会重建指定的临时根目录，不得指向用户工作目录。保留本次开始前的未提交改动；未提交 Git、未覆盖用户安装、未发布。
