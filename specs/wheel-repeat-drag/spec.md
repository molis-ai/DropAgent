# 连续拖拽时轮盘保持可选

2026-09-12 后续：真实 Finder 仍在第二次拖动失败，原因与替代规则见 [wheel-finder-route](../wheel-finder-route/spec.md)。已出现轮盘的范围内由轮盘接货，不能被重叠面板矩形抢占；本文「进入面板就避让」仅作为当时修复记录。

## 目标与完成等级

修复 Finder 第一份文件上架后，拖后一份文件向上移入「加入架子」时，左键仍按着但轮盘消失的问题。交付到本地功能可用：生产轮盘控制器回归通过，正常版重新打包；真实 Finder 手势验证单独记录。

## 当前行为与证据

- 用户在推广演示素材中先拖一份文件，再拖后一份文件；向上选择「加入架子」时轮盘消失，尚未松开左键。
- 只读进程检查确认当时只有一个正常版 DropAgent，排除演示版同时消费拖拽板。
- `EdgeDropController.handleDrag` 每次移动都重新要求系统拖拽板非空；即使已经保存有效 snapshot，板临时为空仍会 `finishExternalDrag → hide`。现有 `wheel-drop-release` 已记录 Finder 拖拽数据暂时读空的问题，但补偿只覆盖松手。
- `updateWheel` 把面板外围 64pt 的唤醒区域也当作轮盘避让区；轮盘上方的瓣即使仍在面板外，也可能被提前藏掉。
- `onPick` 在 `admit` 后读取 `didAdmit`，但同步入库触发的 `hide` 已把该字段归零，导致成功入库仍向 AppKit 返回 false。
- 上述为可由代码重现的缺陷；不把控制器测试当作已观测到的真实 Finder 回调顺序。

## 范围、场景与决策

1. 连续拖入不同文件，每次轮盘在本次拖拽位置出现，向上移入瓣时保持可选，松手后只上架一次。
2. 已识别的拖拽保持到真实结束；共享拖拽板临时为空时保留本次 snapshot，不把它当作鼠标松开。新拖拽仍必须先有有效货物。
3. 面板外 64pt 只用于唤醒面板；轮盘仅在指针实际进入面板窗口时避让。面板内投放继续优先走面板本身。
4. 轮盘投放的返回值记录本次调用已受理，不依赖同步清理后的字段。
5. 保留圆心不接货、离开外圈本次不再出现、顶部标签安全区、关闭轮盘、文件副本入库和不覆盖原件的规则。

非目标：修改轮盘外观、扩大动作类型、Agent/剪贴板自动上架/权限行为、发布 GitHub Release、清理其他任务的未提交改动。

## 输入输出、依赖和文件边界

- 输入：鼠标拖动位置与时间、系统拖拽板、当前轮盘状态、面板实际窗口范围、AppKit drop 回调。
- 输出：轮盘可见/命中状态、稳定的 drop 返回值、现有 Ingest 写入的架子条目和副本。
- `macos/App/EdgeDropController.swift`：修正生命周期和面板避让；允许测试为同一个事件入口传入坐标/时间，不模拟操作系统鼠标。
- `macos/App/WheelE2E.swift`：通过生产控制器、真实 `EdgeDropView` 回调、真实 AppSession/Ingest/ShelfStore 验证连续事件和持久化。
- `macos/App/AppE2E.swift`：接入定向 `--wheel-only` 和完整回归。
- 本 spec 与必要的既有轮盘说明；不改内核业务。

## 验收与验证

- [x] 连续两份真实测试文件都被受理；成功返回 true；架子各一条，副本内容正确、重新加载仍存在、原文件内容不变。
- [x] 第二次已显示轮盘后，拖拽板读空，移入上方瓣不会隐藏；松手使用本次 snapshot，不能误用第一份文件。
- [x] 上方瓣位于面板外 40pt 时仍可选择；进入实际面板窗口才避让，且不抢面板投放。
- [x] 松手后的重复结束通知不重复入库；离开外圈、圆心释放与空拖拽不入库。
- [x] 新回归在修复前稳定失败，在修复后通过；构建、完整 Check 和相关 UI 回归通过。
- [x] 正常版完成打包与签名完整性检查；签名后的应用包再次通过轮盘回归。
- [ ] 重启正常日常实例，并确认真实 Finder 连续拖拽手势。

```sh
CLANG_MODULE_CACHE_PATH=/tmp/dropagent-ui-module-cache swift build --disable-sandbox --product DropAgent --package-path macos
DROPAGENT_ROOT=/tmp/dropagent-wheel-regression macos/.build/debug/DropAgent --e2e --wheel-only
CLANG_MODULE_CACHE_PATH=/tmp/dropagent-ui-module-cache swift run --disable-sandbox --package-path macos DropAgentCheck
CLANG_MODULE_CACHE_PATH=/tmp/dropagent-ui-module-cache bash macos/package-app.sh
codesign --verify --deep --strict macos/dist/DropAgent.app
```

## 假设与开放问题

- 用户尚未确认消失点与面板的相对位置；通过控制器分别验证两个提前隐藏路径，真实 Finder 手势仍需要现场确认。
- 桌面控制工具只能一次完成直线拖拽，不能按住鼠标暂停后读取轮盘再移动；若无法可靠覆盖该手势，不冒充人工实测。

## 2026-09-12 验证记录与交付

- 修复前 `/tmp/dropagent-wheel-before.log`：第一份文件成功入库却返回 false；第二次读空后在松手前隐藏、未入库；面板外 40pt/10pt 过早避让，均失败。
- 修复后 `/tmp/dropagent-wheel-after.log`：同一组生产事件入口及 AppKit destination 回调通过。
- 构建 `/tmp/dropagent-wheel-build.log` 通过。完整 Check `/tmp/dropagent-wheel-check.log` 为 `all passed`；最初受沙盒限制的 NSItemProvider 临时文件访问失败，经环境授权重跑通过，未放宽测试。
- 完整 AppE2E `/tmp/dropagent-wheel-app-e2e.log` 为 `e2e: ok`，包含新增轮盘回归和原有文件/处理/拖出等调用链。
- 打包过程中另一个工作项 `job-output-to-results` 开始修改 JobService 等文件，构建读到了中间状态并报语法错误。本任务不改那部分代码；使用 17:30 已构建且通过上述测试的可执行文件与正常版既有未变更资源组装修复包，不包含之后新增的 Job 输出改动。
- 修复包：`macos/dist/wheel-fix/DropAgent.app`，正常版 bundle ID `local.dropagent`，沿用正常版用户数据目录。当前运行实例及 `macos/dist/DropAgent.app` 未被覆盖，避免与另一个工作项的打包冲突。
- 修复包签名 `codesign --verify --deep --strict` 通过；其 `--e2e --wheel-only` 结果见 `/tmp/dropagent-wheel-packaged-e2e.log`，通过。
- 之前自动启动正常版的操作被审批拒绝（本地构建软件要求启动时确认）；已在修复包完成后请求用户确认重启。真实手势验收仍待加载修复版后完成。
