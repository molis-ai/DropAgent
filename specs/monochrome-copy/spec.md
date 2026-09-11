# 黑白界面与简洁文案

状态：完成（2026-09-11）。完成等级：功能可用；Review 应用已打包，可本地试用。

## 目标与证据

用户要求进一步优化文案，将蓝色视觉改成 Animate UI 式的黑白、简约科技感。当前 Palette 的主按钮、焦点、选中态为蓝色，类型标签另有多种彩色；引导和帮助中有“先放着”“带走吧”“那句话”等较松散表达，使用指南还残留“其他”旧名称。

## 范围与决策

- 保留首次 PDF 体验、确认后运行、复制与拖出、Agent 与权限边界、布局和原生操作行为。
- 统一原生 Palette 和 HTML 原型为纯中性色；浅色用深色主按钮、深色用浅色主按钮。类型用图标与文字区别，错误与状态保留说明和符号。
- 文案按“对象、动作、结果”改写，覆盖欢迎、步骤提示、材料空态、动作说明、结果操作、设置介绍与使用指南，中文和英文同步。原文件／副本／Agent 权限等事实保持准确。
- 简约科技感来自细边框、清楚的字重、紧凑控件和克制动效；不添加装饰渐变、发光或无关图形。
- 文件预览与终端内的用户内容不强制去色；不更改系统偏好。
- 同步 DESIGN、相关产品文档与截图，当前要求替代上一份需求书中的蓝色约束。保留已有未提交工作。

## 输入、输出与文件边界

输入：系统／用户深浅主题、当前 UI 状态、用户选择的语言。
输出：黑白灰 UI、简洁且一致的中英文文案。无新增业务状态或持久化格式。

修改范围：App/Palette、PaperButtons、FileKindMark、Onboarding 与引导 View、Copy、ShelfColumn、ResultStack、确认、设置、AppSession 扩展中的显示文案、编辑器中必要的文本选中颜色；AppE2E 现有主题检查及随文案更新的语言断言、PanelPreview 诊断；prototype/index.html；设计文档、README 与截图。
不修改内核、Agent 协议、权限申请、文件处理或导出逻辑。

## 验收

- [x] 主按钮、悬停、焦点、卡片、状态和标签都使用黑白灰；深浅主题清楚可辨。
- [x] 文案简短、术语一致，按钮说明实际动作，示例确认和结果导出提示清楚，中英文无主要裁切。
- [x] 保留原生动效和减少动态效果分支，纯中性色文字在主要背景上满足可读对比度。
- [x] Swift 构建、现有受影响 UI 回归、Review 打包成功；欢迎、结果、设置和失败状态完成一次批量视觉检查。

## 验证

`CLANG_MODULE_CACHE_PATH=/tmp/dropagent-ui-module-cache swift build --disable-sandbox --product DropAgent --package-path macos`

`DROPAGENT_ROOT=/tmp/dropagent-monochrome-e2e macos/.build/debug/DropAgent --e2e --ui-only`

`macos/.build/debug/DropAgent --preview`

`DROPAGENT_VARIANT=review CLANG_MODULE_CACHE_PATH=/tmp/dropagent-ui-module-cache bash macos/package-app.sh`

HTML 检查内嵌脚本语法；颜色对比通过本轮实际 token 计算。可逆文案与颜色调整不新增测试套件。

## 假设与未包含项

“黑白”指整个界面，不只主按钮。旧版本蓝色截图需更新。系统原生授权窗、第三方终端 ANSI 内容与文件本身不属于应用主题。

## 验证结果

- 通过：Swift 构建与 `--e2e --ui-only`，包含既有终端主题、示例 PDF、语言切换、设置、编辑、自定义动作、失败恢复、PDF／OCR 和文件导出。日志：`/tmp/dropagent-monochrome-build.log`、`/tmp/dropagent-monochrome-e2e.log`。
- 通过：`--preview` 批量检查了欢迎页的深浅主题、英文 800 点面板、示例完成、设置、失败提示与动作栏。代表截图：[浅色欢迎页](../../docs/readme/onboard.png)、[深色欢迎页](onboarding-dark.png)、[深色英文设置](settings-dark-en.png)、[完成状态](result.png)。
- 通过：根据实际 Palette token 计算，主要背景上的正文最低对比度为浅色 4.84:1、深色 6.03:1；主按钮含悬停态最低分别为 13.20:1 和 13.33:1。禁用控件不计入正文对比要求。
- 通过：HTML 内嵌脚本 `node --check`、`git diff --check`。原型同步黑白配色、引导和设置指南，本轮未做浏览器交互回归。
- 通过：`macos/dist/DropAgent Review.app` 打包，`codesign --verify --deep --strict` 校验。本地 adhoc 签名，不作为公证发布物。
- 已有测试中对旧文案逐字匹配的部分改为检查新版界面实际展示的副本、原文件保护、对话权限和导出语义；操作和持久化回归保留。

边界：未修改 Agent、文件处理和权限逻辑；本轮未重复完整实时 Agent／系统授权测试。减少动态效果分支保留，未变更用户系统设置。PDFKit 的离屏截图可能不包含 PDF 正文，实际预览沿用上一轮已验证的原生视图。

后续非阻塞项：现有文件卡的长标题与右侧操作按钮间距仍偏紧；本轮未改变文件卡布局。
