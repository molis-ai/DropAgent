# 结果拖回左列

## 问题

从结果区拖到左边输入列，松手没有进货，也没有「加入架子」高亮。不是产品禁止，是投放类型对不上：`NSItemProvider(contentsOf:)` 把 markdown 当成正文，SwiftUI `onDrop` 要的是文件 URL；左列行自己也能拖，父视图接不住投放。

## 修法

- `itemProvider` 明确登记 `public.file-url` 和真实文件。
- 左列整列和每一行都能 `onDrop`，内部拖也显示「加入架子」。
- Check：结果文件的 provider 能读出文件 URL；`admitProviders` 会复制进货，原结果文件还在。
- 一次投放只进一条。不按 UTI 种类重复进货。

## 非目标

- 不自动把 Job 产出插回左列。
- 不改成挪走结果。

## 验证

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
```
