# 菜单栏第一眼：图标清楚、面板从图标落下、没读到页把 Edge 说进保证范围

## 背景目标

菜单栏小工具每天只露 18 点的图标和一块从图标落下的面板。现在图标是 14pt、只有一档位图，Retina 上发糊；面板只淡入，不像挂在图标下面；没读到当前页时文案只提 Safari / Chrome，但第一版 Edge 是「尽量」、内核已经认 Edge。

## 当前行为与问题证据

- `StatusIcon.image()`：`NSImage(size: 14×14)` 闭包绘制，没有 `@2x` representation。
- `showPanel()` 只把 `alphaValue` 从 0 拉到 1；顶边条已经是「上移 8pt + 淡入」。
- 芯片圆点 6pt，原型是 7pt 外加 3px 浅色圈。
- `CaptureRecovery.noBrowser` 与 `AppSession.captureCopy` 写「Safari 或 Chrome」；`NSAppleEventsUsageDescription` 同样。

## 范围

- 状态栏图标：18pt 模板图，1x + 2x 位图；形状仍是朝下的三角描边 + 底下一根搁板，和 `make-icon.swift` 同一套语言。用黑描边，`isTemplate = true`。
- 面板出现：从图标下方约 8pt 落下并淡入（0.16s easeOut）；收起反向 0.12s。Reduce Motion / `--preview` / `--e2e` / `--capture` 仍立刻出现、不位移。
- 头上状态点：7pt，外圈 13pt、同色 18% 透明度（对齐原型 `.dot`，不是装饰光晕）。
- 没读到前台浏览器：文案改为「Safari、Chrome 或 Edge」。带热键的壳文案仍只在 App 里加 ⌃⌥W。内核常量不含快捷键。
- `Info.plist` 的 Apple Events 说明同样写上 Edge。
- `02` 类型标签补上 DIR / FILE（内核已有）。

## 非目标

- Developer ID。
- 不改四条调用链、不改顶边几何。
- 不为 Impeccable detect 改 `PRODUCT.md`。
- 不把桌面 CLIP 芯片做成正式 App 浮层。

## 使用场景

点菜单栏图标：面板从图标底下落下来。拖 PDF 到图标：图标仍是进货口。Safari / Chrome / Edge 都不在最前时按 ⌃⌥W：提示把其中之一放到最前。

## 方案与关键决策

图标跟 App 图标同一套几何，只缩小成菜单栏模板。面板运动跟已有顶边条同一套（位移 8pt + 透明度），不新发明第二种动效。Edge 写进「没读到页」是因为内核已保证尽量读 Edge，不是把 Brave / Arc / Firefox 升成保证。

## 输入输出与依赖

输入：状态栏按钮、面板 frame、前台浏览器判定。输出：模板图标、面板 frame/alpha、失败文案。依赖现有 `EdgePlacement` 动效节奏和 `CaptureRecovery`。

## 文件 / 模块边界

- `macos/App/AppDelegate.swift`（图标、面板进出）
- `macos/App/PanelRootView.swift`（芯片点）
- `macos/App/AppSession.swift`（热键版抓页文案）
- `macos/App/Info.plist`
- `macos/Packages/DropAgentCapture/Sources/CaptureRecovery.swift`
- `macos/Check/main.swift`
- `02-prototype-design.md`、`specs/capture-progress/spec.md`

## 验收标准

1. `StatusIcon.image()` 尺寸 18×18，含 1x 与 2x representation，`isTemplate == true`。
2. Check：`CaptureRecovery.noBrowser` 含 `Edge`，不含 `⌃⌥W`。
3. 预览 `01-empty` 头上绿点仍在、布局不漂。
4. Check 全绿；`swift build --product DropAgent` 通过。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
```

## 假设与开放问题

菜单栏图标 Check 不 import App，第 1 条用预览进程外的打包 App 目视；实现里把 `StatusIcon` 画进可检查的 `NSImage` 属性，预览窗口本身不显示该图标。
