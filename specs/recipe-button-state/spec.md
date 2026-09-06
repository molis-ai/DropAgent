# 动作格：能点的和不能点的一眼能分

## 背景目标

六个 Recipe 是动作区主控件。禁用的只把字改淡，底还是同一块纸，hover / 按下也没有。原型已经是 hover 加深、disabled `opacity: .38`。选中一张图时，翻译和脱敏看起来仍像能点。

## 当前行为与问题证据

`PanelRootView` 动作格：`.buttonStyle(.plain)`，禁用只改 `Palette.faint`。`QuietButtonStyle` 禁用有 0.45 透明；原型 `.recipes button:disabled { opacity: .38 }`。

## 范围

- 禁用动作格：整格变淡（约 0.45），仍看得见，不藏按钮。
- 能用的：hover 用 `panel-hover` 加深，按下 `panel-press`，发丝边，节奏跟 Quiet 一致。详见 `specs/paper-press/spec.md`。
- 不改 Recipe 接受表、不改四条调用链、不改 accessibilityIdentifier。
- 原型已有同等规则，不发明新文案。

## 非目标

- Developer ID。
- 不把 ZIP / 图接到翻译。

## 使用场景

拖进一张截图：总结、抽取、转 MD 是实的；翻译、脱敏、新交付一眼是暗的。Hover 总结格会略加深。

## 方案与关键决策

动作格用和 Quiet 同一套 ButtonStyle 习惯（`isEnabled`、hover、按下偏移），高度仍由 label 的 48pt 框决定。

## 输入输出与依赖

输入：`hasRecipe` / `recipeFitsSelection`。输出：动作格外观。依赖现有 `chooseRecipe`。

## 文件 / 模块边界

- `macos/App/PanelRootView.swift`
- `macos/App/AppE2E.swift`
- `macos/App/PanelPreview.swift`（现有 `03-idle` / `14-image`）
- 本 spec

## 验收标准

1. 预览 `14-image`：翻译 / 脱敏 / 新交付明显淡于总结 / 抽取 / 转 MD。
2. 预览 `03-idle`：新交付淡，总结不淡。
3. `--e2e`：选中图片 → `recipeFitsSelection(.translate) == false`，`recipeFitsSelection(.summarize) == true`；`recipe-*` identifier 仍在。
4. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

无。
