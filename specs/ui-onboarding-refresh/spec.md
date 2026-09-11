# Onboarding 与全局原生 UI 优化

状态：完成（2026-09-11）。完成等级：功能可用；本次影响的主要路径已做内部试用验证，系统授权与发布级验证不在本轮完成声明内。

> 后续调整：本项的蓝色视觉及部分文案已由 [黑白界面与简洁文案](../monochrome-copy/spec.md) 替代；首次操作路径保持。

## 背景、目标与证据

用户要求优化整个项目的文案、操作、路径、引导、布局、信息、按钮和组件，并询问能否采用 Animate UI。
现有 App 为 macOS 14+ SwiftUI / AppKit；Animate UI 为 React / TypeScript / Tailwind / Motion 组件库，不能直接作为原生依赖。采用其克制的弹簧反馈、选中底片与渐进展开，通过 SwiftUI 实现，保留原生输入、菜单、终端和拖放。

当前首次流程先介绍架子、再抓页授权、最后上架 Markdown 示例。示例总结依赖 Agent，无法证明无 Agent 时的产品价值。主按钮位于小字号进度行中，动作工具与整理工具混排；设置页标签与内容标题缺乏层级，分段控件用 onTapGesture，缺少真实按钮键盘语义。

## 范围、边界与非目标

- 保留：文件在上、内容在中、结果在下、独立对话浮窗；冷白、石墨灰、蓝色（不使用绿色）；现有 Agent 能力和隔离事实；四条调用链。
- 替换：被动翻页介绍与前置授权，改成一个欢迎区和真实样例的连续操作提示；统一按钮层级、设置导航、动作栏、文件卡、结果取走提示及输入控件。
- 忽略：旧 spec 的 GoalBoard 式进度小字、文字箭头主操作、示例必须是 Markdown、授权必须是一拍。这些界面约束由本项替代。
- 不迁移到 WebView / React，不改 Job / Ingest / Shelf / Capture / TUI 公开接口，不自动执行任务或申请权限，不更改用户文件。
- 在已有未提交改动上增量修改；不覆盖或回退其他任务。

## 使用场景与方案

1. 新用户打开，空架子仍可拖入。欢迎区说明“材料放进来，结果拿出去”，展示三步实际路径。主要操作为“用示例 PDF 试一次”，次要操作为“选择我的文件”，可随时跳过。
2. 示例由 App 在 Samples 下生成真实、含可选择文字的 PDF，经现有 Ingest 上架并选中。无 Agent、无网页授权、无网络均可继续。
3. 选中示例时出现“提取文字”明确按钮，调用现有 chooseRecipe(.pdfText)；确认页写清输出、读取副本、写入范围、网络、隔离；用户确认后才调用 confirmRun。
   内容区使用原生 PDFKit 预览实际 PDF，替代“这是 PDF，请在别处打开”的空白说明；可滚动和选中文字，不编辑原文件。
4. 成功后结果显示真实新文件；提示可复制或拖到 Finder。取消确认回到动作提示；失败显示原因和可重试动作。关闭引导后不重复打扰；设置里能主动重新试用示例。
5. 抓网页与 Finder 权限仍在使用准备内，抓取失败仍有按需授权入口；首次不自动弹授权。
6. 已有用户继续原有主流程。动作栏优先展示运行行为，整理工具置后；“其他”改为明确“对话”。设置按用途列出导航、标题和说明，切换保留键盘操作。
   确认和运行期间收起内容预览，让执行范围与取消操作完整可见；查看结果时隐藏原材料动作栏，使用结果需先点“用作材料”，避免把对原材料的动作误认为对结果执行。

## 输入、输出、依赖

输入：onboarded 标记、firstActionHintDismissed、选中材料与结果、任务状态、Agent 能力、系统外观与减少动态效果、语言。
输出：真实 PDF 样例、现有 Job 产生的 pdf.md、可拖出的文件、引导显示状态与原有偏好。样例识别依赖 Samples 目录与真实来源，不向 Job 注入新规则。

## 文件与模块

App 内 Onboarding / 新样例生成文件 / AppSession（首次流程与提示）、PaperButtons / Palette / ColumnHead、ShelfColumn / FileCard / ContentStage / RecipeChooser / RecipeConfirmationView / ResultStack、SettingsPane / SettingsForm / SetupCard、PanelHeader / ComposerBar / AIPane、AppE2E / PanelPreview。同步 prototype/index.html 与产品、设计文档。

## 验收标准

- [x] 空架子欢迎页直达真实样例或选文件；跳过后不会再出现欢迎；没有前置权限或 Agent 要求。
- [x] 无 Agent 状态下样例经 Ingest → .pdfText 确认 → Job → 可读 pdf.md → Pasteboard 真实完成，原 PDF 保持不变；上架不自动运行。
- [x] 取消、重试、完成后取走、提示关闭与设置主动重试路径完整；失败文案不会被引导遮蔽。
- [x] 按钮具备主次层级、hover / pressed / disabled 和键盘语义；卡片选中及设置导航清楚；减少动态效果时关闭位移和缩放动画。
- [x] 原生预览覆盖欢迎、样例、确认、完成、普通文件、失败、设置、对话；深浅主题、英文与较窄面板无主要内容裁切。
- [x] DropAgentCheck、Swift 构建、受影响 App E2E 通过；打包成功；HTML 原型与新版引导一致。

## 验收结果与证据

| 检查 | 结果 | 证据与边界 |
| --- | --- | --- |
| 首次使用与完成闭环 | 通过 | `AppE2E.verifyOnboarding` 在无 Agent 下走正常 Ingest / Job / 文件导出；断言真实中文内容、未自动运行、取消回到待操作、原 PDF 不变、导出内容一致、关闭提示持久化。实际 Review 应用也点击完成“示例 → 确认 → pdf.md”。 |
| 错误恢复与既有操作 | 通过 | `--e2e --ui-only` 覆盖授权／重试入口可见和关闭、设置、编辑、自定义动作、失败重试、PDF、图片 OCR、导出。日志 `/tmp/dropagent-ui-e2e.log`：`e2e: ui ok`。修复了 WorkPane 在提供授权／重试时反而隐藏 ErrorBanner 的问题。 |
| 原生视觉与语义 | 通过 | `--preview` 生成中文／英文、深浅主题、800 点窄面板、确认、结果、设置、对话等状态；最终截图改用每次独立数据根目录，并按实际面板高度截取。现场检查 PDFKit 真实预览及设置 Button 语义、搜索 Tab 焦点。减少动态效果分支经代码检查，未切换系统偏好做人工复测。 |
| 核心回归 | 通过 | `/tmp/dropagent-ui-check.log`：`DropAgentCheck: all passed`。可选网页实时抓取记录了 `captureFailed`，未将它算作授权链路通过。 |
| 构建、打包与签名 | 通过 | Swift 构建成功；`DROPAGENT_VARIANT=review bash macos/package-app.sh` 生成 `macos/dist/DropAgent Review.app`；`codesign --verify --deep --strict` 通过。本地 adhoc 签名，非公证发布物。 |
| 原型与文档 | 通过（限定） | HTML 同步首次路径、主次按钮和无 Agent 的 PDF 动作；提取脚本经 `node --check` 通过。原型仍为模拟数据，本轮没有补浏览器端交互回归。需求、设计及 app-shell 文档已同步。 |

代表截图：[欢迎页](../../docs/readme/onboard.png)、[完成与取走](result.png)、[深色英文设置](settings-dark-en.png)、[对话](conversation.png)。

未运行：系统 TCC 授权重新授予、所有控件的系统全键盘导航人工遍历、系统减少动态效果开关实测、完整实时 Agent／网页抓取 E2E、公证与全新机器安装。它们不影响本次已验证的离线样例闭环，但不能据本轮结果宣称整个产品已达到可发布级别。

## 验证命令

`cd macos && swift run DropAgentCheck`

`cd macos && swift build --product DropAgent`

`DROPAGENT_ROOT=/tmp/dropagent-ui-e2e macos/.build/debug/DropAgent --e2e --ui-only`

`macos/.build/debug/DropAgent --preview`

`bash macos/package-app.sh`

## 假设与开放问题

Animate UI 的使用意图按“同等级的组件与交互质感”执行，不因参考库更换产品技术栈。允许生成示例 PDF；此前“不做示例 PDF”是已被当前优化目标取代的旧任务边界。TCC 系统授权本轮不重做；不会把诊断 UI 快照等同于真实授权验证。
