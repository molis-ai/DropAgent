# 悬停预览：左右也能滑

## 背景与目标

预览卡只有纵向滚动条。宽表格、长代码行、横图看不到完整内容，触控板左右滑没有反应。一骏要求预览卡也支持左右滑动。

完成等级：功能可用。

## 当前行为与问题

- `HoverPreview` 在正文高过 320pt 时才放 `ScrollView(.vertical)`。
- 卡片视觉宽度锁死 276pt。段落、代码、JSON 都按这个宽度折行。
- 表格超过 4 列才有内层横向滚动，且 `showsIndicators: false`，外层仍只有竖条。
- 图 `scaledToFit` 后 `maxWidth: .infinity`，被压进卡宽。

`specs/hover-stay-scroll/spec.md` 的「过长可滚」现只覆盖上下。本 spec 补左右。指针停留、位置、暂留仍以既有 spec 为准。

## 范围

- 预览卡视口最多 276×320。内容超出时：上下、左右都能滑，滚动条按轴出现。小图不撑满卡宽，卡片随图缩小，不留大块空纸。
- 段落、标题、列表、引用仍按卡内宽度换行，不必为了读一句去横滑。
- 表格、代码、JSON、图片按自身宽度；比卡宽时左右滑。
- 只宽不高：也出横向滚动，不因为不够高就没有 ScrollView。
- 仍不打开链接、不嵌网页、不拉远程图。

## 非目标

- 不把预览改成完整结果页。
- 不改结果区正文的滚动。
- 不让普通段落变成一行硬拉横条。

## 方案

- 有任一方向溢出时用 `ScrollView([.vertical, .horizontal])`，`scrollBounceBehavior(.basedOnSize)`。
- 测量用未锁卡宽的同一套正文：段落 `maxWidth` 为卡内宽，表格/代码/图取固有宽。
- `HoverPlacement.needsScroll` 同时看高和宽。
- compact 表格不再套一层横向 ScrollView，避免嵌套抢手势。
- 标题和类型仍钉在顶部。

## 验收

1. 过长正文：仍可上下滚完，竖条还在。
2. 宽表、长代码行或横图：可左右滑，有横条；不是裁掉右边。
3. 普通短段落：不出空的横条。
4. 大内容卡宽仍是 276；小图可以更窄。位置仍贴纸面左侧，不翻到右侧。
5. `swift run DropAgentCheck` 与 `--e2e` 通过。

## 验证

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```
