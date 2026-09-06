# 壳层补全与抽取输出

## 背景目标

内部试用还差几处会绊脚：装好 Codex 后要重启才看得到；抽取结果常被模型包在围栏里；面板突然弹出；分隔条每次都回到默认高度。没发现 Codex 时只能去右键菜单里选路径。快捷键注册失败时界面仍写 ⌃⌥D / ⌃⌥W。没选中时输入栏左侧空着一块。顶边投放条突然出现。分隔条 VoiceOver 当成按钮。

## 当前行为与问题证据

- `showPanel` 现在会 `refreshPresence()`；JSON 围栏、面板淡入淡出、`panel.json`、可点「未发现 Codex」已落地。
- `HotKeyCenter.register` 原先忽略 `RegisterEventHotKey` 的 OSStatus，占用时页脚仍写 ⌃⌥D / ⌃⌥W。
- composer 无选中时用空字符串占 32pt。
- 顶边投放条 `orderFront` 无入场。
- 分隔条 `.isButton`，VoiceOver 不能调高度。

## 范围

- 打开面板时重新 `discover` Codex。
- Recipe 产出 `.json` 时去掉围栏，只留下能 parse 的 JSON；不是 JSON 文件不动。
- 面板开合短淡入淡出；Reduce Motion / `--preview` / `--e2e` 关掉。
- 分隔条高度存 `panel.json`（跟 `DROPAGENT_ROOT` 走）。
- 头上「未发现 Codex」可点，打开选择可执行文件。
- 快捷键没注册上时，页脚、空态、动作区、菜单改成图标/菜单入口，不假装按键还能用。
- 顶边投放条第一次出现时短上滑+淡入；拖动中已显示则只改 frame。Reduce Motion / preview / e2e 关掉。
- 输入栏无选中不占「N 项」空位。
- 分隔条 VoiceOver 为可调高度，增减 16pt 并写入 `panel.json`。

## 非目标

- Developer ID、Safari 真机授权。
- 不改四条调用链。
- 不解析 TUI 画面、不模拟键盘点终端菜单。

## 使用场景

1. 另一款 App 占用了 ⌃⌥D：打开面板后页脚写「点菜单栏图标打开」，不写 ⌃⌥D。
2. 没选中条目时，输入框贴左，不留计数空位。
3. 从屏幕中部往顶边拖文件：投放条从下方滑入；继续贴顶移动时条跟着屏幕走、不再重播入场。
4. VoiceOver 焦点在分隔条上，调高/调低改变列表高度并记住。

## 方案与关键决策

- 注册结果写进 `AppSession.hotKeyToggleOK / hotKeyCaptureOK`；预览与 e2e 默认 true，只有 `AppDelegate` 写入真实结果。
- 文案集中在 `HotKeyCopy`，页脚、空态、动作区、菜单共用，避免三处各写一套。
- 顶边入场 0.15s 上移 8pt + 淡入；松手或离开命中区后下次再入场。

## 输入输出与依赖

- 输入：`RegisterEventHotKey` OSStatus、鼠标拖到顶边、选中条数、VoiceOver 增减。
- 输出：页脚/空态/菜单文案、composer 布局、顶边窗口 frame/alpha、`panel.json`。
- 依赖：Carbon 热键、`EdgePlacement`、`AppSession.persistChrome`。

## 文件 / 模块边界

- 只改 `macos/App` 与本 spec。内核包与四条调用链不动。
- Check 不 import App；热键文案用预览图 `12-hotkeys` 对照，不在 Check 里复述字符串。

## 验收标准

1. `RegisterEventHotKey` 非 `noErr` 时，页脚和第二行不出现对应快捷键字样。
2. 两条都失败：页脚写「点菜单栏图标打开，用菜单抓页」；菜单项是「抓取当前页」不含 ⌃⌥W。
3. 未选中时 composer 左侧没有 32pt 空白。
4. 顶边条首次出现有上滑淡入；已显示时只更新位置；Reduce Motion 时直接出现。
5. 分隔条 VoiceOver 可调，值是当前高度点数，增减后写入 `panel.json`。
6. 已有：打开面板 rediscover；JSON 去围栏；面板开合动效；高度持久化；未发现 Codex 可点。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-preview-root ./.build/debug/DropAgent --preview
```

预览需含 `12-hotkeys.png`（两条快捷键都失败时的页脚）。

## 假设与开放问题

- Carbon 热键收不到 System Events 合成按键；§10.4 成功路径仍要真人按 ⌃⌥D / ⌃⌥W。
- 本机没有 Developer ID 证书时，试用包继续 adhoc `local.dropagent`。
