# 菜单栏图标悬停有系统高亮

## 背景目标

`02` / 原型：菜单栏图标 hover 和面板打开时都有浅色底。现在图标上盖了一层 `StatusDropView` 接拖入，系统按钮自己的 hover 进不去。不拖的时候图标是死的。

## 当前行为与问题证据

`StatusDropView` 铺满 `NSStatusBarButton`，只在 `draggingEntered` 刷蓝。`refreshStatus` 只在面板显隐时 `highlight`。鼠标划过图标没有反馈。

## 范围

- `StatusDropView` 用 tracking area 收 `mouseEntered` / `mouseExited`。
- 悬停：高亮状态栏按钮。
- 离开：面板关着就取消高亮；面板开着保持（和原型 `.open` 一样）。
- 拖入仍刷蓝，进货链不变。
- `--preview` / `--e2e` / `--capture` 不依赖这块（它们不走菜单栏图标）。

## 非目标

- Developer ID。
- 不改顶边条。
- 不为 detector 改 `PRODUCT.md`。

## 使用场景

鼠标扫过菜单栏图标：图标亮一下。点开面板后，即使鼠标离开，图标仍保持按下态。

## 方案与关键决策

不把 overlay 从 hit test 拿掉（松手后那一下还要吞掉，免得刚进货又把面板关掉）。只补 hover 高亮，拖入蓝底照旧。

## 输入输出与依赖

输入：鼠标进出、面板是否可见。输出：`NSButton.highlight`。依赖现有 `StatusDropView`。

## 文件 / 模块边界

- `macos/App/AppDelegate.swift`
- `macos/App/AppE2E.swift`
- 本 spec

## 验收标准

1. `--e2e`：`StatusDropView` 有 `mouseEnteredAndExited` tracking。
2. `--e2e`：悬停高亮按钮；离开且面板关着时取消；面板开着离开仍高亮。
3. Check 全绿；拖到图标仍是进货。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

菜单栏真机 hover 仍需目视；e2e 用普通 `NSButton` 搭同一套 `StatusDropView`。
