# Finder 拖向上方瓣时轮盘提前消失

状态：修复已实现并加载，等待用户确认真实 Finder 连续拖动（2026-09-12）。用户在最新工作台版本再次报告真实 Finder 拖动失败；沿用已授权修复范围，保留新版视觉。

## 目标与证据

轮盘出现后，左键持续按住，从中心拖向上方「加入架子」应保持可见可投放；松手只复制入架一次。完成等级为功能可用，生产回归与真实 Finder 验证分别记录。

- 当前运行 PID 50768 启动于 20:14:38，正常包二进制生成于 20:07:42，已加载新版；不是旧进程未重启。
- 当前主面板处于淡出状态，Finder 前台；控制器的面板避让仅检查 `window.isVisible + frame.contains`，没有区分实际内容范围与投影留白、遮挡。
- 既有 `WheelE2E` 直接同步调用拖动入口，没有真实事件循环或 Finder 回调，因此不能验证 watchdog 与原生目标切换时序。
- 初始排查假设：实际进入面板/透明边界触发避让；或 watchdog/原生结束回调提前清理。先记录实际关闭原因，不叠加猜测补丁。

运行证据已确认：用户在诊断版中第一份成功、第二份失败。`/tmp/dropagent-wheel-route-live.log` 记录第一份在 `(9,73)` 松手入架；后两次在左键仍按下、相对中心 `(-1,52)` / `(-1,49)` 时触发 `conceal-panel`，其中一次最终在 `(-1,97)` 松手，仍被判为面板范围而跳过轮盘入架。没有 watchdog 提前结束或离圈记录。故本次根因是已出现的轮盘被主面板矩形避让抢占，不再追查其他假设。

## 范围与方案

1. 允许暂时在轮盘控制器记录状态转换、鼠标相对位置、面板命中与结束原因，不记录文件路径/内容；定位后删除临时诊断代码。
2. 轮盘一旦出现，在中心、通往六瓣的路径与既有外圈容差内保持拥有本次选择；这段区域内不唤醒/避让重叠主面板。上方瓣松手由轮盘接货，不能再次被面板矩形拦截。
3. 保留中心不投放、离开外圈取消、敏感剪贴板过滤、副本入库与原件不变。拖动从主面板内开始，或已经离开轮盘范围，主面板仍正常接货；旧的「任何时候进入主面板矩形就隐藏轮盘」规则被此优先关系替代。动作与外观不变。
4. 回归通过生产控制器和原生 destination API，覆盖本次真实失败时序/边界；确认修复前失败、修复后通过。

## 文件与依赖

`macos/App/EdgeDropController.swift`、`EdgeDropView.swift`、`EdgePlacement.swift`、`AppDelegate.swift`/`AppDelegate+Panel.swift`、`WheelE2E.swift` 中的相关路径；本 spec。仅有证据需要时改对应文件，不改业务包。现有未提交改动保留。

## 验收

- [x] 找到用户场景对应的提前关闭路径，有运行证据。
- [x] 正常中心→上方瓣移动保持可选，松手正确复制入架；原件不变。
- [x] 本次失败场景修复前回归失败、修复后通过；重复拖动、离圈/中心取消、面板接货不退化。
- [x] 定向构建与 `--e2e --wheel-only` 通过；按影响补充检查。
- [x] 正常 App 打包并完成签名完整性检查，加载新版本。
- [ ] 用户确认修复版的真实 Finder 连续拖动。

命令：`cd macos && swift build --product DropAgent`；`DROPAGENT_ROOT=/tmp/dropagent-wheel-route-test macos/.build/debug/DropAgent --e2e --wheel-only`；`bash macos/package-app.sh`。


## 验证记录

- 现场诊断：用户确认第一份成功、第二份失败；记录 `/tmp/dropagent-wheel-route-live.log`，提前关闭原因为 `conceal-panel`，当时左键仍按下。临时诊断代码已从最终源码移除。
- 修复前：`/tmp/dropagent-wheel-route-before.log` 稳定报上行路径隐藏、按钮隐藏、错误唤醒面板、松手未入架与副本缺失。
- 修复后：`/tmp/dropagent-wheel-route-after.log` 通过相同场景，并覆盖直接拖进面板、离开外圈、中心取消、连续文件、暂时空拖板、重复结束通知、副本内容与原件不变。
- 构建：`/tmp/dropagent-wheel-route-build-after.log` 通过。首次构建因另一处正在更新 `WorkbenchSidebar.swift` 被 Swift 中断；待文件更新落稳后重跑通过，未回退那部分工作。
- 打包：`/tmp/dropagent-wheel-route-package.log` 通过；`codesign --verify --strict macos/dist/DropAgent.app` 通过。签名后的 App 再次运行 `--e2e --wheel-only` 通过，日志 `/tmp/dropagent-wheel-route-packaged.log`。
- 已结束临时诊断实例，重新启动正常 App 使用原有数据。原生界面可见原有两份材料。修复后现场手势结果待用户反馈；不把生产事件回归当作人工手势通过。
