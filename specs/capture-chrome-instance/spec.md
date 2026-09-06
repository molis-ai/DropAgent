# 抓页：多实例 Chrome 不误读；隔离窗可验

## 背景目标

`01` §12 保证 Safari、Chrome。Safari 已有 `--e2e` 真窗证据。Chrome 不能用 `tell application "Google Chrome"` 或 AX 去读用户正在用的主窗。本机常有第二份 `--user-data-dir` 实例；AppleScript 按应用名说话，会打到默认那份（用户主 Chrome）。

## 当前行为与问题证据

`AppleScriptBrowser` 在 AX 失败后执行 `tell application "Google Chrome"`。窗口列表里同时存在：

- pid 92265：用户主 Chrome（Notion 等），禁止激活、禁止 AX、禁止 AppleScript
- pid 63540：`--user-data-dir=/tmp/dropagent-chrome-profile` 的隔离实例，窗只有 1800×39 条，不能当真页

两条都是 `com.google.chrome`。AX 按 pid 读是对的；AppleScript 不分 pid。

## 范围

- Chromium 系（Chrome / Edge / Brave）：同一 bundle 上多于一个进程时，跳过 AppleScript，只信该 pid 的 AX。
- `--capture` 可用 `DROPAGENT_CAPTURE_PID` 钉死目标 pid，避免 DropAgent 抢前台后误冻到别的窗。
- 用新的隔离 Chrome 打开 `https://example.com/`，只激活该 pid，跑 `--capture`，架子出现 WEB 条。

## 非目标

- 不激活、不 AX、不 AppleScript 用户主 Chrome。
- 不改 Safari e2e。
- 不把抓页改成 skip。
- Developer ID。

## 使用场景

人在自己的 Chrome 看一页，按 ⌃⌥W。本机若只有这一份 Chrome，AX 失败时仍可走 AppleScript。若同时开了另一份用户数据目录的 Chrome，不要把默认实例的标签读进架子。

验收时：隔离实例在最前，抓到 example.com，不动主 Chrome。

## 方案与关键决策

1. `shouldUseAppleScript(kind:targetPID:runningBundleIDs:)`：`usesAppleScript == false` → 否；否则数同一 bundle 的进程，大于 1 则否。
2. `CaptureLaunch.freeze()`：环境变量 `DROPAGENT_CAPTURE_PID` 优先，且必须能解析成浏览器 Kind。
3. Live：杀掉旧隔离进程，新 `--user-data-dir` 开 example.com，只 `NSRunningApplication.activate` 该 pid。

## 输入输出与依赖

输入：隔离 Chrome pid、example.com。输出：WEB 条，`url.txt` 为 `https://example.com/`。依赖辅助功能。

## 文件 / 模块边界

- `macos/Packages/DropAgentCapture/Sources/SystemCaptureAdapters.swift`
- `macos/App/CaptureLaunch.swift`
- `macos/Check/main.swift`
- `design/modules/capture.md`
- 本 spec

## 验收标准

1. Check：单进程 Chrome 允许 AppleScript；两个 `com.google.chrome` 不允许；Chrome+Canary（不同 bundle）仍允许目标那份；Arc 不允许。
2. Check：`CaptureLaunch` 钉 pid 的解析不依赖前台（单测纯函数即可）。
3. 隔离 Chrome 在最前且地址为 example.com 时，`--capture` 写出 `WEB` / Example Domain / example.com；过程中用户主 Chrome pid 仍是原 pid、不把该窗放到最前。
4. 不 `tell application "Google Chrome"`。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_CAPTURE_PID=<isolated-pid> DROPAGENT_ROOT=/tmp/dropagent-capture-chrome macos/.build/debug/DropAgent --capture
```

## 验证记录（2026-09-06）

隔离 Chrome pid 62453（`--user-data-dir=/tmp/dropagent-chrome-profile`，窗名 Example Domain）钉死抓页：

```
DROPAGENT_CAPTURE_PID=62453 DROPAGENT_ROOT=/tmp/dropagent-capture-chrome macos/.build/debug/DropAgent --capture
capture: WEB WEB Example Domain https://example.com/
```

`url.txt` 21 字节（含换行）、`page.md` 168 字节、`snapshot.png` 80389 字节。用户主 Chrome pid 92265 仍在，窗名仍是 Notion。未 `tell application "Google Chrome"`。Check 全绿。隔离实例随后已退出，主 Chrome 未动。
