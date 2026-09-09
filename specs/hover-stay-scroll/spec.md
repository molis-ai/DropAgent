# 悬停预览：指针在卡内不消失，过长可滚

## 背景与目标

悬停预览已经能出正文，但窗口不接收鼠标：指针一离开文件卡就关，也无法滚动。长文稿只看到被裁掉的上半截。

完成等级：功能可用。

## 当前行为与问题

- `HoverPreviewWindow`：`ignoresMouseEvents = true`。
- `HoverPreview`：`allowsHitTesting(false)`，正文 `maxHeight: 220` 后 `.clipped()`。
- 文件卡 `onHover(false)` 立刻 `hideHover`。
- 预览贴在面板纸面左侧（不够则右侧），与纸面有 8pt 空隙。

`specs/hover-readable/spec.md` 里「窗口仍忽略鼠标 / 过长截断」和 `specs/hover-left-of-panel/spec.md` 里「不让预览可点」由本 spec 覆盖。

## 范围

- 指针进入预览卡：预览保持显示，可滚动看完全文（仍受 `ItemPeek` 字数上限）。
- 指针离开预览卡、也不在对应文件/结果卡上：预览关掉。
- 关面板、开设置、打开文件、进货：立刻关掉，不等延迟。
- 位置仍贴纸面左侧（不够则右侧）。视觉卡宽不变；窗口向纸面伸出一条透明桥，盖住 8pt 空隙，避免穿过空隙时提前关掉。
- 仍不打开链接、不嵌网页、不拉远程图。

## 非目标

- 不把预览改成完整结果页。
- 不从卡片画安全三角形；不挡文件卡本身。
- 不改内核业务规则，不覆盖原件。

## 方案

- 预览窗接收鼠标。离开卡片后的暂留时长见 `specs/hover-linger/spec.md`；这段时间内进入预览则取消关闭。
- 指针在预览内：忽略来自卡片的关闭请求。
- 正文高过 320pt 时窗口封顶 320，内部可滚；不超过则按内容高度，不出现空滚。左右滑动见 `specs/hover-h-scroll/spec.md`。
- 标题和类型钉在顶部，图和正文一起滚。

## 验收

1. 悬停出预览后，把指针移进预览卡：预览还在。
2. 预览里过长正文可以滚动看完，不是裁掉下半截。
3. 指针离开预览、也不在该卡片上：预览关掉。
4. 关面板或开设置：预览立刻关掉。
5. `swift run DropAgentCheck` 与 `--e2e` 通过。

## 验证

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```
