# 工作台端到端复查修复

状态：已实现。完成等级 3。唯一需求书。依据本会话「发现的问题都修」，覆盖 2026-09-12 工作台复查列出的功能缺陷与路径摩擦。

## 背景目标

端到端复查没有发现必现丢文件或双进货，但确认态会丢在架子上、整合仍可能交差、Finder 松手可能弹一下，投放/轮盘/底栏/侧栏也不顺。这次把复查列出的问题修完，不另开产品方向。

## 当前行为与问题证据

见会话复查与 `.impeccable/critique/2026-09-12T14-51-13Z__macos-app-panelrootview-swift.md`。

## 范围与非目标

做：确认草稿同步、完成口播收口、投放已进货仍回 true、投放罩变轻、轮盘进出场对齐、闲时透明度、对话/确认高度、底栏分流与文案、搜索过滤架子、不适用动作不占位、结果重名、侧栏行操作、焦点不抢终端、⌘V 脚注。

不做：可缩放面板、运行中允许隐藏、把对话区改回投放分区、Mac App Store / 云端。

## 使用场景

1. 多选材料点总结，再点结果或另一份材料：确认抽屉消失，侧栏不再留虚线圈。
2. 整合口播「已整合三份材料。」不当交付。
3. Finder 拖进面板：能看见底下目录；松手进材料，Finder 不回弹。
4. 单选时底栏没有「整合」；「对话」和动作分开，帮助写明不会生成新文件。
5. 搜索既过滤架子，也能添加本机文件；⌘V 脚注写明贴的是当前剪贴板。

## 方案与关键决策

1. `cancelConfirm` 清全部 `.confirm`；焦点离开这批材料时清掉未选中的确认草稿。
2. 短完成口播只要有「已把 / 已将 / 已写入 / 已生成 / 已整合」或英文 wrote/written/created/saved/combined 即拒绝，不再要求出现「文件」。
3. 同一次拖已进货后，`admitPasteboard` / 轮盘 `performDragOperation` 返回 true。
4. 投放罩半透明，标题「加入材料」，副文案「发给终端请拖到轮盘」。轮盘瓣同样用这两句。
5. 轮盘退场淡出（e2e / 减少动态效果仍瞬间关掉）；瓣弹跳上限 0.22s、缩放 1.06。
6. 闲时透明度 0.72，仍降到普通窗口层。
7. 确认抽屉打开时对话高度降低，避免预览被挤没。
8. 底栏：不适用的 Agent 动作不占位；对话前加分隔，帮助写明是终端会话。
9. 搜索框过滤材料/结果/剪贴板，Spotlight 菜单仍用于添加。
10. 结果侧栏标题对重名编号；行操作叠在行尾，不挤掉文件名；隐藏帮助写清「只从列表拿掉」。
11. 选材料/结果/剪贴板只卸正文编辑器焦点，不卸终端。
12. 侧栏脚注写明 ⌘V 粘贴当前剪贴板。

## 文件 / 模块边界

App 壳：`AppSession+Job`、`+Shelf`、`+Workbench`、`+Admit`、`+ActionBar`、`PanelRootView`、`WorkbenchSidebar`、`WorkbenchDetail`、`RecipeChooser`、`DropZoneOverlay`、`EdgeDropController`、`EdgeDropView`、`EdgePlacement`、`PanelIdle`、`WheelAction`、`HeaderSearch`、`HotKeyCopy`、`SettingsGuideCopy`、`StageEditor`。

内核：`RecipeOutput`、`ResultRecord`、`JobService`。

文档：`DESIGN.md`、`02-prototype-design.md`、`design/modules/app-shell.md`、`design/modules/job.md`、`specs/brief-deliverable-body/spec.md`、`specs/idle-panel-recess/spec.md`。

## 验收标准

1. 两份材料确认后改选结果：两份都回到 idle，抽屉关闭。
2. `looksLikeDeliverable("已整合三份材料。") == false`；「这是总结」仍为 true。
3. mouseUp 先于 `performDragOperation` 进货时，后者返回 true 且不双进。
4. 单份材料时 `barSlots(organizing: false)` 不含 `.brief`。
5. `ResultRecord.uniqueTitle("brief.md", among: ["brief.md"]) == "brief 2.md"`。
6. `PanelIdle.alpha == 0.72`。
7. `cd macos && swift run DropAgentCheck`；`swift build --product DropAgent`；`--e2e --workbench-only` 与 `--e2e --wheel-only`。

## 假设

发给终端仍只走轮盘，这次只把入口写清楚，不把对话区改回投放区。
