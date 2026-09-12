# 宁静的效率工具配色

状态：完成（2026-09-11）。完成等级：功能可用；本地 Review 应用已更新并实际运行。

## 背景与目标

用户认为纯黑白有视觉疲劳，希望为图标增加颜色，整体呈现 peace、宁静的效率工具感。用户随后明确纠正“不要绿色”，当前方案排除绿色。保留现有布局、文案、动作流程和窗口行为；把上一轮纯黑白限制替换为低饱和语义配色。完成等级：本地功能可用、可实际体验的 Review 应用。

## 方案与边界

- 基底采用暖纸白、中性炭灰；正文为墨灰/雾白，辅助文字仍满足可读对比。避免大片纯黑、纯白和高饱和彩色底。
- 低饱和雾蓝承担主按钮、焦点、选择和完成状态。状态还保留文字与符号，错误使用柔和陶土红、等待使用麦色。
- 文件类型小图标与标签、动作图标、设置导航使用固定色组：雾蓝（文字/处理）、钢蓝（网页/翻译/连接）、麦色（文件夹/快捷动作）、灰紫（图片/对话）、陶土（PDF）。正文和整个按钮不随图标变成彩虹；图标也不用绿色。
- 原生 AppKit 编辑器、终端底色、选区与 SwiftUI 共用语义颜色；不改终端 Agent 自身输出的 ANSI 色。
- 同步 `prototype/index.html` 的现有颜色角色，更新 `DESIGN.md`、`02-prototype-design.md` 与本轮截图。旧 v0.1.0 Release 记录作为历史保持；本次不自动重新发布安装包。

输入：现有浅/深主题、选中/悬停/禁用/错误状态。输出：统一颜色 token 与在现有组件上的映射，无数据或业务接口变化。

允许修改：Palette、文件类型标记、RecipeGlyph/动作按钮、设置导航、错误/状态图标、设置完成标记、原型配色、相关设计说明、现有主题回归断言及必要的预览场景。

## 验收与验证

- [x] 浅/深主题的面板、内容、按钮、编辑区和终端观感一致；正文不因柔和而模糊。
- [x] 常用图标有清楚且克制的颜色，主操作与状态容易识别，禁用不保留鲜明彩色。
- [x] 主要文字对比 ≥4.5:1，图标和焦点 ≥3:1；仍有文字/形状等非颜色线索。
- [x] 一次成组检查浅/深、密集文件/动作、设置、错误和窄窗；发现问题合并修正，最多再确认一次。
- [x] 构建、现有 `--e2e --ui-only` 通过，Review 应用可打开；原型脚本语法通过。

不为颜色值新增实现镜像测试；仅更新现有终端主题契约断言。用户最新偏好覆盖 `monochrome-copy` 的纯黑白限制，其他已验证行为沿用。

## 最终验证

| 验收项 | 结果与证据 |
| --- | --- |
| 最终主题 | 暖纸白 `#f8f7f4`、墨灰正文 `#383a43`、雾蓝主操作 `#586582`；深色为炭灰 `#27272d`、浅雾蓝主操作 `#b5c0e0`。无绿色 token 或图标映射。 |
| 可读性 | 按 sRGB 相对亮度计算面板、分区、悬停、选择、编辑区和终端上的最小对比：浅色正文/辅助文字 4.55:1，深色 5.11:1；主按钮文字 5.54/7.15:1；类型标签 4.72/5.42:1；彩色图标 4.49/5.40:1；原生文字选区 8.25/5.53:1。禁用状态单独降对比。 |
| 色觉模拟 | 使用 [Machado 模型矩阵](https://github.com/njsmith/colorspacious/blob/master/colorspacious/cvd.py) 在 linear sRGB 中模拟 protan/deutan/tritan 的 100 级配色；主要文字最小对比分别为 4.52/4.57/4.54:1。文件类型仍有标签和不同符号，选择有边框，错误有图标、原因和恢复按钮。 |
| 原生视觉检查 | 成组检查欢迎页浅/深、800pt 英文、密集文件浅/深、设置浅/深、错误、对话。颜色面积克制，正文清楚，禁用动作退为灰色，无本轮引入的遮挡；无需额外视觉修补。最终运行中的 Review 窗口也已读取确认。 |
| UI 回归 | `DROPAGENT_ROOT=/tmp/dropagent-calm-blue-ui macos/.build/debug/DropAgent --e2e --ui-only` 通过；覆盖示例、错误恢复入口、设置、编辑、动作、失败、PDF、OCR 和导出。日志 `/tmp/dropagent-calm-ui.log`。 |
| 构建与包 | `CLANG_MODULE_CACHE_PATH=/tmp/dropagent-ui-module-cache swift build --disable-sandbox --product DropAgent --package-path macos` 通过。`DROPAGENT_VARIANT=review CLANG_MODULE_CACHE_PATH=/tmp/dropagent-ui-module-cache bash macos/package-app.sh` 通过；`codesign --verify --deep --strict 'macos/dist/DropAgent Review.app'` 通过。 |
| 原型与范围 | 内联脚本提取后 `node --check /tmp/dropagent-calm-prototype.js` 通过；同步现有 CSS 颜色角色和遗漏的动作图标名称映射。`git diff --check` 通过。未改业务接口、窗口定位、权限或内核。 |

当前截图：[浅色文件区](files.png)、[深色文件区](files-dark.png)、[欢迎页](onboarding.png)、[深色欢迎页](onboarding-dark.png)、[深色设置](settings-dark-en.png)。

本轮未重跑浏览器原型的端到端交互、系统 TCC 授权、外部 Agent 的真实执行或公开发布流程；本轮变化限于配色，原生已有 UI 回归已重跑通过。GitHub v0.1.0 发布物保持原版本。
