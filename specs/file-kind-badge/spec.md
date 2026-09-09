# 文件卡类型：图标 + 颜色

## 背景与目标

文件卡上的类型几乎是灰字。文稿卡只有一行 `MD`，其它卡是一张素纸加 7pt 字母。一骏要求用图标和颜色区分类型。

完成等级：功能可用。

## 当前行为

- 有正文的卡：底部 `displayTag`，`Palette.muted`，无色、无图标。
- 其它卡：32×40 纸形 + 底部色条字母。
- 图片卡已有缩略图。
- `02` 曾写「不用文件图形，颜色只在标签上」。本任务改为：类型用小图标 + 色标签，仍不给整卡上色，不用绿。

## 范围

- 所有文件卡、结果卡的类型识别。
- 图标用 SF Symbol；色用现有 `tagFill` / `tagInk`，可略加强对比。
- 有正文的卡：底部色芯片（图标 + 标签）。
- 无正文的卡：左侧 32 色块图标，取代素纸。
- 图片仍用缩略图。
- 原型同一套。

## 非目标

- 不改 kind 规则、进货、拖出。
- 不给整卡铺底色，不用绿色。
- 不引入自定义插画。

## 方案

- `FileKindGlyph.symbol(kind:tag:)` 按类型/扩展名选符号。
- `FileKindMark`：大方标或小芯片。
- 颜色仍只在标记上；文字标签保留，不单靠颜色。

## 验收

1. PDF / 图 / 链接 / 网站 / MD / 剪贴板 / 文件夹 / ZIP 能靠图标和色标签扫出来。
2. 正文卡底部是色芯片，不是灰字。
3. 整卡背景仍是纸色；选中描边仍是蓝。
4. `swift run DropAgentCheck` 与 `--e2e` 通过。

## 验证

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```
