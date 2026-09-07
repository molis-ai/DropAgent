# 左输入不变，右结果追加

## 背景目标

跑完 Recipe 后要还能对**同一份输入**再操作。磁盘上原件本来就不覆盖；卡住的是左列那一行被改成 `summary.md` / `done`，六个动作不能再点。

## 当前行为与问题证据

`JobService` 成功后 `patch` 同一条目：`title = outputFileName`、`kind = outputKind`、`status = done`、`output = outputFile`。左列不再是原件。`recipeBatch` 不含 done。`isDoneTakeaway` 把动作区换成「打开结果」。右边「结果」Tab 看的是被换掉的那条。

`01`：结果作为新 Artifact 回到托盘，原件不动。实现把 Artifact 写进了输入行。

## 范围

- Job 成功 / Hash 不符 / Agent 失败：输入行回到 `idle`，**不改** title、kind、parts、sourceURL。产出追加为 `ResultRecord`，出现在右栏结果区。
- 点左列 → 动作对着原件，可再跑 Recipe、可发给终端（走原件）。
- 点右栏某一结果 → 预览 / 拖出 / 复制走该产出；发给终端走该产出文件，不把左列标成 sent。
- 多份材料「新交付」：一条结果，`sourceItemIDs` 含全部输入。
- `shelf.json` 改为 `{ items, results }`；仍能读旧的 `[Item]` 数组。已是 `done` 的旧行不迁移，仍走原来的拿走动线。
- 预览 `06-result`：左列仍是原文件名；结果在右栈。`06b-done-work`：动作区仍有 Recipe。
- `--e2e` recipe / extract / brief：输入 title 不变；结果在栈里；拖出的是产出文件。

## 非目标

- 不改四条调用链；不是新包。
- 不把结果再插进左列。
- 不做三栏。
- 不自动覆盖原路径。
- 不把 TUI「已进终端」改成结果栈。
- 不迁移旧 `done` 行的原名（已经丢掉）。

## 使用场景

PDF 在左列。总结跑完：左边还是这份 PDF，右边多一条 `summary.md`。再点翻译：左边仍是 PDF，右边两条。点左边看动作；点 `summary.md` 看正文并拖出。

## 方案与关键决策

`DropAgentShelf.ResultRecord`：id、sourceItemIDs、recipe、title、kind、output、isolationShown、createdAt、status（done|failed）、failureReason。

Job 不再把输入改成产出。隔离档写在结果上，输入回到 idle 时 `isolationShown = none`。取消任务不写结果。

右栏在 composer 上方常驻结果栈（无结果则不画）。`paneFocus`：`.input` / `.result`。最近一次点击决定中间看什么。

## 输入输出与依赖

输入：现有 Item、Job.start、结果 Tab 预览、拖出/复制、TUI.send。  
输出：输入行保持原件；结果栈追加；拖出/复制/发送随焦点。  
依赖：Shelf 持久化、Job、App 面板。Pasteboard 仍吃 `Item`（结果用 `takeawayItem()`）。

## 文件 / 模块边界

- `macos/Packages/DropAgentShelf`：ResultRecord、ShelfStore results、新旧 json
- `macos/Packages/DropAgentJob/Sources/JobService.swift`：写结果、还原输入
- `macos/Packages/DropAgentTUI`：`extraFiles`，不 patch 架子
- `macos/App/AppSession.swift`、`PanelRootView.swift`、`PanelPreview.swift`、`AppE2E.swift`
- `01-requirements.md`、`02-prototype-design.md`、`design/modules/{shelf,job,ai-pane}.md`、`PRODUCT.md`、`prototype/index.html`
- 本 spec

## 验收标准

1. Check：Job 成功后输入 `idle` 且 title 仍是原名；`results()` 有对应产出文件；原件 Hash 不变。Hash 不符：输入 idle，结果 `failed` 且有 output。Agent 失败：输入 idle，结果 `failed`。Brief：两份输入都 idle，一条 `brief.md`。旧 `[Item]` json 仍能 load。
2. 预览 `06-result` 左列不是 `summary.md`；`06b-done-work` 有 Recipe 网格。
3. `--e2e` recipe：架子上仍是源文件名；结果栈有 `summary.md`；拖出落地是 `summary.md`。
4. App 不 import Capture。不自动覆盖原路径。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

旧 `done` 行保持现状。结果栈按时间新到旧。删除左列不级联删结果。
