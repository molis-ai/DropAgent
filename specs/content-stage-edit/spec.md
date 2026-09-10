# 内容台可编辑：改的是副本

## 背景与目标

点文件后，中间内容台现在只是只读预览。人已经把材料放上架子，常常要改几个字再跑动作。编辑必须落在 DropAgent 自己的 Inbox / Jobs 副本上，不能写回用户原件。

完成等级：功能可用。

## 当前行为

- 选中文件或结果后，`ContentStage` 用只读 `ResultPreview` 显示正文。
- 文稿、剪贴板、`page.md`、结果文字都只是看。
- 原件路径记在 `sourceURL`；架子上的可读文件在 `Inbox/<id>/` 或 `Jobs/<id>/output/`。

## 范围

- 内容台还是现在那块。选中后先按阅读态展示渲染后的 Markdown（或原有预览）；再点正文才进入编辑。不另开窗口，不另放保存按钮。Esc、换条、跑动作回到阅读态。
- 停笔约 400ms 写入副本；换条、跑动作、拖出、复制、发给终端、关面板前先落盘。
- 只写 Inbox / Jobs 里的文字副本。`sourceURL` 原件不动。
- 运行中、确认中锁住，仍只读。
- 第一版可编：文稿、剪贴板、txt / md / json / 代码、网页 `page.md`、结果文字产出。空文件也可编。
- 第一版只读：图片、PDF、文件夹、链接、二进制、抽出的 HTML。
- 结果区浮窗（若还在）仍只读。悬停预览仍只读。

## 非目标

- 不做富文本、Markdown 所见即所得、图片/PDF 标注。
- 不自动把修改写回用户原件。
- 不改 Job / TUI 的隔离和 Prompt 规则。

## 方案

- 内核 `DropAgentIngest.StageEdit`：判定可写 URL、读、防抖写、flush。
- 可写条件：状态不是 running / confirm；文件在 Inbox 或 Jobs 内；扩展名是文字；UTF-8 无空字节；不是 html/htm。网页只编 `page.md`，不编 `url.txt`。
- App `ContentStage`：默认可写材料仍用 `ResultPreview` 阅读；点正文后提示「改的是副本，原件不动。」+ `NSTextView`。不可写时一直只读。编辑器自带滚动，不套一层 ScrollView。
- 点总结 / 拖出 / ⌘C / 发给终端前 `StageEdit.flush()`，避免最后几键没落盘。

## 验收

1. 选中 txt / md / 剪贴板 / json / 代码 / 有 `page.md` 的网页 / 文字结果：内容台先是阅读态（Markdown 已渲染）；点正文后可打字；停笔后副本内容更新。Esc 或换条回到阅读态。
2. 同一条的 `sourceURL` 原件字节不变。空文件也能写入。
3. 图片、PDF、文件夹、链接、HTML、二进制：仍只读。
4. 运行中、确认中：不能改。
5. 换条、跑动作、拖出前，未满 400ms 的修改也已落盘。
6. `swift run DropAgentCheck` 与 `--e2e` 通过。

## 验证

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```
