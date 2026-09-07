# 按钮整格可点，不只点在字上

## 背景与目标

设置页和纸面 Quiet / Primary 按钮看起来是一整块，但点击只落在文字上才生效。Recipe 格已经有 `contentShape`，另外两套样式没有。

## 当前行为

- `QuietChrome` / `PrimaryChrome`：`frame` 把底撑满，没有 `contentShape`。SwiftUI 仍按 label 文字做命中。
- 设置「完成」、浅色/深色/跟随系统：`.plain` 同样只点字。

## 范围

- Quiet、Primary 与 Recipe 一样，在裁切后加 `contentShape(Rectangle())`。
- 设置完成、分段选项、头上 Tab：整块可点。
- 不改调用链、不改按钮文案和视觉尺寸。

## 验收

1. 「选择文件夹…」「完成」、浅色/深色/跟随系统、中文/English：点按钮空白处与点字同样生效。
2. 「在副本中运行」、粘贴、发送：点格子空白处生效。
3. Check 全绿；e2e 通过。

## 验证

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```
