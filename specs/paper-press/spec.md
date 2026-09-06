# 纸面控件：按下要加深，窗口真圆角

## 背景目标

纸面按钮的 hover / 按下应当像按进纸里（变深），不是把底变浅。动作格要和 Quiet 一样有发丝边。面板本身是 12pt 圆角纸，不能是方窗套圆内容。

## 当前行为与问题证据

- `RecipeChrome` / `QuietChrome` 用 `panel2.opacity(0.88)` 做 hover：纸透出来，格子变浅。原型是 `#e2e2e0` 加深。
- 动作格没有描边；Quiet、原型 Recipe 都有 `1px` 发丝边。
- 作曲家聚焦描边是墨色 55% 透明；原型是 `--text`。
- `NSPanel.backgroundColor` 仍是整张方纸；SwiftUI `clipShape(12)` 盖不住窗口四角。
- 预览 PNG 顶上约 32pt 全宽透明：titled 窗口的标题栏安全区把纸面顶下去，截图和实机都会在头上留一条空洞。

## 范围

- 能用的 Quiet / Recipe：hover 用 `panel-hover`（`#e2e2e0`），按下用 `panel-press`（`#d2d2d0`）。禁用仍整格约 0.45 透明。
- 动作格加发丝边，对齐 Quiet 与原型。
- 输入框聚焦描边用墨色，不半透明。
- 面板 / 预览 / e2e 窗口背景透明，host 12pt continuous 圆角。
- 正式菜单栏面板：`borderless` NSPanel，不挂系统标题栏；预览 / e2e 仍可用 titled 方便诊断。
- 根视图忽略标题栏安全区，纸面从窗口顶铺满，预览顶上不再留 32pt 空洞。
- 原型 Quiet / Recipe hover、active 用同一组色。
- 不改四条调用链、不改 Recipe 接受表、不为 detector 改 `PRODUCT.md`。

## 非目标

- Developer ID。
- 不改选中行左侧 2px 墨条（原型已有）。

## 使用场景

鼠标滑过「总结文件」格子变深一点，按下再深一点。禁用的翻译格仍明显更淡。点开菜单栏，纸的四角是圆的，不是方窗。

## 方案与关键决策

填充色进 `Palette`，不靠降低透明度。窗口圆角做在 host layer。正式面板去掉 titled 边框，阴影仍走 `hasShadow`，出现时 `invalidateShadow`。

## 输入输出与依赖

输入：hover / pressed / isEnabled、窗口 host。输出：加深的纸面控件、圆角面板。依赖现有 ButtonStyle。

## 文件 / 模块边界

- `macos/App/Palette.swift`
- `macos/App/PanelRootView.swift`
- `macos/App/AppDelegate.swift`
- `macos/App/PanelPreview.swift`
- `macos/App/AppE2E.swift`
- `prototype/index.html`
- `DESIGN.md`
- `specs/composer-ime/spec.md`（外观从炭灰蓝边改成白底墨边）
- 本 spec

## 验收标准

1. 预览 `14-image`：翻译 / 脱敏 / 新交付明显淡于总结 / 抽取 / 转 MD；能用的格子有发丝边。
2. 预览 `03-idle`：动作格有发丝边，不是无边色块。
3. `RecipeChrome` / `QuietChrome` 不再用降低 `panel2` 透明度做 hover。
4. 作曲家聚焦 stroke 是 `Palette.text`。
5. 预览 `01-empty` 顶边中线不是透明条：纸面从圆角内开始，不是先空 32pt。
6. Check 全绿；`--e2e` 过；`recipe-*` identifier 仍在。`DropAgentPanel` 无边框且能成为 key（输入法）。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

无。
