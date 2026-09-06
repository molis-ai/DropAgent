# 抓页进行中与失败独占

## 背景目标

⌃⌥W 抓当前页要联网、截图，常要数秒。现在快捷键等抓完才 `showPanel`，中间没有反馈，看起来像没按上。失败时错误条还叠在上一条的 Recipe /「打开终端」上。

## 当前行为

- 热键：`await captureCurrentPage()` 之后才打开面板。
- 抓页开始前会冻结 `BrowserFront.current()`，但面板出现太晚。
- `offerPrivacySettings` 为真时，动作区仍渲染选中条的网站预览和终端 CTA。

## 范围

- 冻结前台浏览器 **先于** 打开面板 / AX 提示。
- 抓取中：面板立刻出现，动作区只显示「正在抓当前页」，不造假 WEB 条。
- 读失败：动作区只留失败原因和「去授权 / 再试 / 好」，点「好」后才回到选中条。
- 没有前台浏览器：不弹授权，说明把 Safari / Chrome / Edge 放到最前。
- 辅助功能和自动化都没有：先停在授权说明，不造「没读到页」的假失败，也不去拉网页。
- 失败文案按 AX / 自动化 / 浏览器种类区分。`--capture` 仍尝试抓一次（不弹面板、不弹 AX）。看门狗在全局队列 25s，主线程卡住也能结束进程。
- AX 读前台页有 1.2s 墙钟上限；先读 `AXStandardWindow`，跳过 Chrome「翻译此页」这类 sheet。超时则放弃 AX、走 AppleScript 或失败，避免在 Chrome 树上挂死。
- Brave 与 Chrome 同类，尽力读当前页；抓正文用 Safari 形态的 User-Agent。
- 窗口截图优先 ScreenCaptureKit（该 pid 最大的可见窗口），失败再退回 CG 截图（同样选最大窗，避开 Chrome「翻译此页」sheet），再退回按 URL 渲染。3 秒内拿不到就降级，不挂死。
- `--capture` 在 `NSApplication` 起来之前冻住前台浏览器；自己变成前台后，窗口列表按 pid 优先记 layer 0，避免把 Safari/Chrome 的状态栏窗当成唯一窗口后报 `front=none`。
- `WindowSnapshotting.snapshotFrontWindow` 改为 async，避免在主线程同步等截图。`CaptureService.captureFrontBrowser` 对外签名不变。

## 非目标

- 不改 `CaptureService.captureFrontBrowser` 的对外签名。
- 不在架子上插入占位条目。
- 不宣称本机已授权或已抓到 Safari。

## 方案

`prepareCapture()` 记下 `CaptureLaunch.frozen ?? BrowserFront.current() ?? lastCaptureTarget` 并置 `isCapturing`。`--capture` 在 `main` 里先 freeze。热键/菜单：prepare → showPanel → `captureCurrentPage()`。`captureCurrentPage` 只用已冻结 target，不再在面板抢前台之后重问谁在最前。

## 验收

- 预览有抓取中画面；09 失败画面不再出现「打开终端」；11 能看到「原件中途变了」。
- Check 仍全绿；试用包重新签名。
