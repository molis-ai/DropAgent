# 菜单栏图标保持可见

## 背景目标

DropAgent 没有 Dock 图标，菜单栏漏斗是日常入口。重启后漏斗会进控制中心折叠，人以为 App 没开。要在系统允许的范围内把图标钉住。

完成等级：功能可用。挤满的菜单栏仍可能进折叠，那是系统规则，不宣称能霸占可见那一排。

## 当前行为与问题

- 启动只创建 `NSStatusItem`，不强制可见、不记住位置、允许 Command 拖走。
- `StatusChrome.hideForPrompt` 把所有 `level >= statusBar` 的窗（含菜单栏 extra）`orderOut`，授权结束后 `finishPromptKeepHidden` 不恢复。
- macOS 26 把第三方 extra 交给控制中心；没有保存位置时，挤满就进 `»` 折叠。

## 范围

- 每次创建、激活、打开面板：漏斗 `isVisible = true`。
- 记住位置（`autosaveName`）。不允许 Command 拖出菜单栏。
- 授权 / 选文件只动面板和顶边窗，不藏、不降菜单栏 extra。
- `--preview` / `--e2e` / `--capture` 行为不改。

## 非目标

- 不改 Dock、不注册登录项、不用私有 API 抢别人的 extra 位置。
- 不阻止用户在系统设置里关掉「在菜单栏中显示」。关掉后，再打开 App 会重新钉上。

## 使用场景

打开 DropAgent Review：漏斗在菜单栏。点辅助功能「允许」：漏斗还在。Command 拖图标：拖不走。菜单栏极挤时可能仍在 `»` 里；拖出来一次，下次启动还在原位。

## 方案

- `autosaveName = DropAgentStatusItem`，随后 `isVisible = true`（覆盖上次藏起的状态）。
- `behavior` 不含 `removalAllowed`。
- `StatusChrome` 捕获窗时跳过 `NSStatusBarButton` 所在窗。
- `applicationDidBecomeActive` 和 `showPanel` 再钉一次。

## 文件 / 模块

- `macos/App/AppDelegate+StatusItem.swift`、`AppDelegate.swift`、`AppDelegate+Panel.swift`
- `macos/App/PanelChrome.swift`
- `macos/App/AppE2E.swift`

## 验收

1. 启动后 `statusItem.isVisible == true`，且不能 Command 拖走。
2. `hideForPrompt` 后 extra 仍可见、透明度仍为 1；面板仍会藏。
3. Check 与 `--e2e` 通过。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设

macOS 26 挤满时仍可能把 extra 放进折叠；钉住的是「进程在就登记为显示」，不是永久占可见槽。
