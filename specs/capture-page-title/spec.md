# 抓页不要把「未命名」当成网站名

## 背景目标

`01` §12、`02` §7：架子上的 WEB 条用页面标题作名字。本机 `--e2e` 已能抓到 example.com 的 url/正文/截图，但条目标题和拖出文件夹是「未命名」。Safari 刚打开时辅助功能读到的是空标签页名，不是文档标题。

## 当前行为与问题证据

`e2e-capture-web`：WEB 条 `未命名`，`url.txt` 是 `https://example.com`，`page.md` 正文已有 `# Example Domain`。桌面落到 `未命名/`。`web-drag-name` 要求文件夹名含 Example，e2e 只断言文件夹名等于 `item.title`，标题错了也会绿。

## 范围

- 浏览器标题若是空、整段 URL、或占位（未命名 / Untitled / 新标签页 / 浏览器名）：改用 HTML `<title>`；再没有就用 host。
- 浏览器标题可用时仍用它（已加载完成的标签）。
- AX 窗口名去掉 ` — Safari` / `- Chrome` 这类后缀后再判断。
- `--e2e`：example.com 的 WEB 标题和拖出文件夹名含 Example，不能是「未命名」。
- 不改四条调用链。

## 非目标

- Developer ID。
- 不保证已登录墙后的正文。
- 不解析 TUI。

## 使用场景

Safari 打开一页立刻按 ⌃⌥W：架子上是页标题，拖到桌面的文件夹也是这个名字。

## 方案与关键决策

标题解析放在 Capture：先信浏览器，不行再用这次已经拉到的 HTML。不另发一次网络。

## 输入输出与依赖

输入：浏览器 URL+标题、抓到的 HTML。输出：`PageCapture.title`。依赖现有 `admitCurrentPage` / 拖出按标题命名。

## 文件 / 模块边界

- `macos/Packages/DropAgentCapture/`
- `macos/Check/main.swift`
- `macos/App/AppE2E.swift`
- `specs/capture-app-e2e/spec.md`、`specs/web-drag-name/spec.md`
- 本 spec

## 验收标准

1. Check：浏览器报「未命名 — Safari」、HTML `<title>Example Domain</title>` → `PageCapture.title == Example Domain`；浏览器已是「Keep Me」则不覆盖。
2. Check：占位标题且 HTML 拉失败 → 标题是 host，不是「未命名」。
3. `--e2e`：example.com 的 WEB 标题含 Example；拖出文件夹名含 Example，内有 url.txt / page.md / snapshot.png。
4. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

Safari 中文空标签是「未命名」。英文 Untitled 一并当作占位。
