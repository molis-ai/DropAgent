# Native 面板：文件在上、结果在下、对话浮窗

## 背景与目标

设计原型已改成上下架。本 work item 把同一套 IA 落到 `macos/App`，不丢现有能力。

完成等级：功能可用。真实面板按新结构工作；允许视觉细节与原型仍有差距。

`depends_on`：`specs/shelf-stack-layout/spec.md`（原型与文案已对齐）

## 当前行为

三栏：左输入列表、中动作/终端/预览、右结果。默认宽 800。动作常驻中间。

## 范围

- 只改 `macos/App` 与壳文档（`design/modules/app-shell.md`、`03-tech-architecture.md` 窗口/命中描述）。
- 产品文案位置：文件 / 结果区 / 放到上面当材料 / 对话。
- 保留：Recipe 确认与隔离四行、运行/取消、PTY、拖入拖出、复制、隐藏/删除、剪贴板、轮盘、设置/就绪、引擎芯片、快捷键。

## 非目标

- 不改 `macos/Packages/` 内核业务规则。
- 不覆盖用户原件。
- 不把对话浮窗做成第二扇独立 NSPanel（同一窗口里两张卡 + 空隙即可）。
- 不追求与 HTML 原型像素级一致。

## 方案

单窗口、透明底。里面两张 12px 冷白卡，中间约 10pt 露出桌面。

| 原位置 | 新位置 |
|--------|--------|
| 左列输入 | 上卡横向文件卡，「文件」 |
| 中列 Recipe | 选中后出现的动作栏 |
| 确认 / 运行中 | 动作栏下的工作条，不打开浮窗 |
| 「其他」底栏 | 下卡「对话」浮窗 |
| 中列终端 / 预览 | 浮窗里的终端卡片；悬停看预览 |
| 右列结果 | 文件下方「结果区」，无结果则不出现 |
| 拖回左列 | 「放到上面当材料」：`Ingest.admit` 复制进文件行，结果仍留着 |

默认宽 1040。高度随内容，设置/就绪仍用约 640。关「工作」：动作、工作条、浮窗都藏。关「结果」：结果区藏。

## 允许修改

`macos/App/**`、`design/modules/app-shell.md`、`03-tech-architecture.md` 窗口与拖入命中、`01-requirements.md` / `02-prototype-design.md` 里过时的左右栏位置句、`specs/shelf-stack-layout/spec.md` 完成等级。

## 验收

1. 未选文件：只有文件行；无动作栏、无浮窗；无结果则无结果区。
2. 选中文件：动作栏出现。点总结仍先确认（选项 + 读/写/网络/隔离），确认后结果出现在结果区，不打开浮窗。
3. 点「其他」：文件架下方出现对话卡，中间露出桌面；可发给终端。圆角 12、分区条「对话」、下划线输入，不是胶囊。
4. 选中结果：出现「放到上面当材料」；复制进文件行，结果区仍保留；原件不动。
5. 悬停文件或结果：预览弹出，不被面板裁切。
6. 轮盘、拖到桌面、⌘V、设置、就绪、无终端禁用动作仍可用。
7. `cd macos && swift run DropAgentCheck` 与受影响的 App E2E 断言通过。
8. 再点已选文件或结果：取消选中。双击用系统默认方式打开（见 `specs/click-toggle-open/spec.md`）。

## 验证

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
```

有显示时再跑：`DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/dist/DropAgent.app/Contents/MacOS/DropAgent --e2e`
