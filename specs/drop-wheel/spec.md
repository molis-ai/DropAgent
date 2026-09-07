# 拖放轮盘：鼠标周围六瓣快捷操作

## 背景与目标

全屏拖标签时，顶边整条黑条会抢走落点。进货口不能只靠菜单栏图标。上一版做成了旁边一颗「加入架子」圆盘，和要的不一样：要的是钉在指针周围的**轮盘**，一圈快捷操作；指针离开外圈，轮盘立刻消失，拖还给底下的 App。

## 当前行为与问题证据

- 现在是单按钮圆盘，贴着指针跟着走。
- 没有「发给终端」和 Recipe 瓣。
- 跟着走时出不了圈，消失时机不好判断。

## 范围

- 系统拖约 `0.18s` 后，轮盘**钉在当时鼠标位置**，不再跟随。
- 六瓣，从正上顺时针：加入架子、发给终端、总结、抽取、翻译、转 MD。圆心是空洞，光标先落在洞里。
- `hitTest` 只在启用的瓣上命中。空洞、圆外、方窗口四角、禁用瓣都不接拖，让给底下的 App。
- 指针走进启用的瓣：该瓣高亮。松手 = 做那件事。不开关面板。
- 指针离圆心超过外圈 + `16pt`：轮盘消失，这次拖不再出现。
- 松手在空洞或圈外：不进货。
- 屏幕最顶 `80pt` 内这次拖还没出过轮盘时，不出现（换标签）。
- 拖到已打开的面板上：藏轮盘，用面板自己的落点。
- **加入架子：** `admitPayload`（http(s) 抓页）。
- **发给终端：** `admitPayload(capturePages: false)` 再 `sendToTUI`。没 Agent 则只进架子并说明。
- **四个 Recipe：** 进货后用该动作默认选项立刻 `Job.start`，不走确认页、不弹面板。材料种类不合则进架子并说明，不硬跑。
- 没 Recipe 入口时，四个动作瓣禁用（看不见命中）。没 Agent 时「发给」禁用。
- 只有拖拽板里真有货才出现：文件 / 图 / 字 / URL，或浏览器标签 / 承诺文件。仅有 `public.item`、Chromium dummy、空条目，或改窗口大小这种按住拖，不算。
- 松手结束这次拖（进货或没进货）后清掉 `NSPasteboard(name: .drag)`，并记下 changeCount；下次同一份残留货不再出轮盘。不清系统剪贴板。
- 点菜单栏、拖窗口标题栏、改窗口大小：不出现。
- 同一次拖不进两次。Chrome 承诺数据备份仍有效。
- 不改四条调用链的方向：进货仍 `Ingest.admit`，发送仍 `TUI.send`，Recipe 仍 `Job.start`。
- 设置 → 外观可关掉轮盘；关掉后菜单栏图标和输入列表仍接拖。详见 `specs/shelf-only-layout/spec.md`。

## 非目标

- 脱敏、新交付不进轮盘。
- 不摇一摇、不按修饰键。
- 不为轮盘单独开确认窗。
- Developer ID、解析 TUI、模拟键盘。

## 使用场景

1. 全屏 Chrome 左右换标签：轮盘不出现。
2. Finder 拖 PDF，约 0.2 秒指针周围出现轮盘。拖进「加入架子」松手：进货。往外一甩：轮盘没了，文件还能丢到桌面。
3. 拖进「发给」：进架子并送给当前终端，面板不因此打开。
4. 拖进「总结」：进架子，用默认篇幅在副本里跑。
5. 松手在圆心空洞：什么都不做。
6. 拖完一个 PDF 进架子后，再按住拖窗口边缘改大小：轮盘不出现。
7. 拖完后系统 ⌘C 剪贴板仍是用户原来的内容。

## 方案与关键决策

轮盘是钉住的 pie menu，不是卫星圆盘。窗口盖住外接正方形，但只有瓣上的像素接拖。出圈即这次拖结束轮盘。Recipe 用默认选项直接跑。

## 输入输出与依赖

输入：全局拖拽、拖拽剪贴板、鼠标相对圆心的距离和角度。  
输出：六瓣命中、`admitFromWheel`。  
依赖：`IncomingDrop`、`ClipboardPayload`、`Job.start`、`TUI.send`。

## 文件 / 模块边界

- `macos/App/EdgePlacement.swift`
- `macos/App/WheelAction.swift`
- `macos/App/EdgeDropView.swift`
- `macos/App/EdgeDropController.swift`
- `macos/App/AppSession+Admit.swift` / `AppSession+Job.swift`
- `macos/App/AppE2E.swift` / `SettingsGuideCopy.swift`
- `prototype/index.html`
- 产品事实与设置文案
- 本 spec

内核包 API 不改。

## 验收标准

1. `--e2e`：圆心是空洞；正上中圈是第 0 瓣（加入架子）；外圈之外 `leftRange`；顶边 80pt `inTabSafeZone`。
2. 设置文案有「轮盘」「六瓣」；英文有 `drop wheel`。轮盘不开关面板。
3. 原型是六瓣轮盘，出圈消失，不是单圆盘。
4. Check 全绿。
5. `draggedTypes` 仍含 `WebURLsWithTitlesPboardType` 与 `public.item`。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

真人：换标签不出轮盘；拖进一瓣进货或开跑；甩出外圈轮盘消失且桌面仍能接文件。

## 假设与开放问题

空洞要靠 `hitTest == nil` 把拖让给别的 App。若某系统版本窗口仍吃掉空洞里的 drop，菜单栏图标和面板仍是进货口。
