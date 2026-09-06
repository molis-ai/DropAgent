# 分隔条好拖；顶边条不要玻璃

## 背景目标

`02` 分隔 7px。视觉要对，但 7pt 命中太窄，拖架子高度会打滑。顶边投放条还叠着一层白高光，和已锁定的「不做玻璃」打架。

## 当前行为与问题证据

- `PanelRootView` 分隔条 `frame(height: 7)`，命中区就是这 7pt。
- `EdgeDropView` 有 `CAGradientLayer` 白高光，和刚从面板去掉的那层同类。

## 范围

- 分隔条外观仍是 7pt 发丝 + 中间胶囊；交互命中上下各扩约 6pt，不把布局撑厚。
- 顶边投放条去掉高光，纸面 + 发丝边 + 偏移阴影保留。
- 原型分隔条同样扩大命中，不发明新规则。
- 不改四条调用链、不改 56–320 高度范围。

## 非目标

- Developer ID。
- 不为 detector 改 `PRODUCT.md`。

## 使用场景

架子上有两条，拖分隔条把终端井拉大。拖到屏幕顶边投放：看到一张纸，不是玻璃条。

## 方案与关键决策

SwiftUI `contentShape(.interaction, Rectangle().inset(by: -6))` 只扩命中。顶边条删 `shine`。

## 输入输出与依赖

输入：现有分隔条手势、顶边 `EdgeDropView`。输出：更好拖、无玻璃。依赖现有 `setListHeight`。

## 文件 / 模块边界

- `macos/App/PanelRootView.swift`
- `macos/App/AppDelegate.swift`
- `prototype/index.html`
- 本 spec

## 验收标准

1. 预览 `01-empty` / `03-idle`：分隔仍是细线，不是一条厚杠。
2. 预览 `01-empty` 顶边不在画面里；代码里 `EdgeDropView` 不再加高光层。
3. Check 全绿；`--e2e` 过；顶边几何仍 36pt 高。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

无。
