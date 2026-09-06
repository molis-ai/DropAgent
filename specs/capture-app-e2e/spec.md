# App 端到端：Safari 有地址时出现 WEB 条

## 背景目标

`03` §10.4：快捷键在 Safari 有地址时出现 WEB 条；读失败有明确失败，不造假条目。内核 Check 用桩验过「失败不造条」，`liveCapture` 在 Cursor 前台会 `captureFailed`。本机已证实：Safari 打开 `https://example.com/` 时，打包 App 和 debug 二进制 `--capture` 都能写出 `WEB Example Domain`。壳上的 `captureCurrentPage`（热键同一条链）还没在 `--e2e` 里跑过。

## 当前行为与问题证据

`prepareCapture` 在 DropAgent 自己在最前时，会从屏幕上已有的浏览器窗推断前台。Safari 若已打开，不能用「直接 `captureCurrentPage()`」当失败用例。失败必须显式传入 `target == nil`。成功必须先把 Safari 放到最前，再走与热键相同的 `prepareCapture` → `captureCurrentPage`。

## 范围

- `AppSession` 增加显式 target 入口，供 e2e 模拟「没有前台浏览器」。
- `--e2e`：无前台浏览器 → 明确失败、架子不增 WEB 条。
- `--e2e`：`open -a Safari https://example.com/` → 激活 → 抓页 → 架子上一条 WEB，标题/地址是 Example Domain；不造假文件。
- 只动 Safari，不激活用户主 Chrome。不关 Safari。
- 测完删掉该 WEB 条，后面仍走 Grok 发送。

## 非目标

- 不模拟 Carbon 热键（合成键收不到）。
- 不卸 TCC、不改 AX 提示。
- Developer ID。
- 不保证已登录墙后的正文。

## 使用场景

人在 Safari 看一页，按抓页快捷键，架子出现网站条。没把浏览器放到最前时，说明白失败，不插假条目。

## 方案与关键决策

成功路径不注入 Capture 桩，走真 `AppleScriptBrowser` + 联网拉 `example.com`。失败路径不读 `BrowserFront.current()`，避免误抓已打开的 Safari。

## 输入输出与依赖

输入：本机 Safari、`https://example.com/`。输出：架子 WEB 条目、`errorText`。依赖现有 Ingest.admitCurrentPage。

## 文件 / 模块边界

- `macos/App/AppSession.swift`
- `macos/App/AppE2E.swift`
- 本 spec

## 验收标准

1. `--e2e`：显式无前台浏览器时，架子 WEB 条数量不变，错误含「没读到当前页」，有再试。
2. `--e2e`：Safari 在最前且地址为 example.com 时，出现 `kind == web` 的 idle 条，标题含 Example（不能是「未命名」），`url.txt` 在，地址是 example.com。
3. `--e2e`：随后 Grok 发送仍过。锁屏导致 Safari 放不到最前时：先打印 `capture deferred`，Grok 发送仍要跑完，最后以 `safari not front` 失败。
4. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

壳超时 240s：抓页成功后再走 Grok 发送，不能被 120s 掐掉。

## 假设与开放问题

本机 DropAgent 已有辅助功能 + 控制 Safari。无授权时这条会失败，不改成跳过。锁屏或前台是 `loginwindow`、Safari 放不到最前时：抓页成功路径记失败，仍跑完后面的 Grok 发送，最后以抓页失败退出。不把抓页改成跳过。
