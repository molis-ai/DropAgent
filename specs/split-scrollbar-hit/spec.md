# 分隔条不要盖住滚动条

## 目标

中间栏和结果栏之间能拖到宽度。滚动条只负责滚动。

## 问题

系统 `NSScroller` 叠在中间栏右缘。SwiftUI 热区、zIndex、向右扩命中都压不过它，点到的还是滚动条。

## 行为

- 分隔条独占 16pt 空缝，用 AppKit 命中，不和 ScrollView 重叠。
- 中间栏、输入列的 ScrollView 右侧留 `scrollGutter`，滚动条收在缝左边。
- 不再向两侧负 padding 扩热区。

## 验收

1. `splitWidth >= 16`，`scrollGutter >= 12`。
2. `swift build --product DropAgent`；`swift run DropAgentCheck`。
