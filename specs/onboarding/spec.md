# 第一次打开：动作区讲清三步

## 背景目标

空面板上半已经能拖入。下半只有一句「拖到上方加入架子」，人不知道放下之后要做什么、结果从哪拿走、原件会不会被改。`first-open` 只保证面板弹出来，明确不做多页引导。

## 当前行为与问题证据

正式 App 第一次打开：架子空，动作区是 `workIdleHint`。没有「放上来 → 选动作 → 拖走」，也没有一份可点的示例材料。

## 范围

- 架子空、还没有 `onboarded` 标记：动作区换成一屏三步 +「试一次」/「跳过」。不是多页、不放教练标记、不放示例 PDF。
- 「试一次」走进货链 A：写入 `先读我.md`，`Ingest.admit(urls:)`，材料进架子。随后标记已看过。
- 「跳过」、或任意一次成功进货：写下 `onboarded`。之后空态回到现有 `workIdleHint`。
- 启动时架子上已有条目：直接视为已看过，避免清空后再弹出。
- `--preview` 先拍 `00-onboard`，再跳过，再拍现有 `01-empty`。
- `--e2e` 验 `shouldShow`、试一次进货、标记；不把 `onboarded` 当成 `opened`。
- 原型加评审场景「第一次」。
- 不改四条调用链。

## 非目标

- 多页向导、教练标记、示例 PDF。
- Developer ID。
- 不自动跑 Recipe。

## 使用场景

第一次打开空面板：先看见架子是投放口，下面三步告诉人放下之后怎么处理、结果怎么拿走。想动手就「试一次」。

## 方案与关键决策

教学留在动作区，架子仍是投放口。一份 Markdown 文稿，不是 PDF。

## 输入输出与依赖

输入：架子是否为空、是否已有 `onboarded`。输出：动作区文案或示例条目。依赖现有 `Ingest.admit`。

## 文件 / 模块边界

- `macos/App/Onboarding.swift`
- `macos/App/AppSession.swift`
- `macos/App/PanelRootView.swift`
- `macos/App/DropAgentPaths.swift`
- `macos/App/PanelPreview.swift`
- `macos/App/AppE2E.swift`
- `prototype/index.html`
- 本 spec

## 验收标准

1. 预览 `00-onboard`：动作区有「放上来」「选动作」「拖走」和「试一次」；架子仍是「拖到这里」。
2. 预览 `01-empty`：跳过之后动作区回到「加入架子」，不含「试一次」。
3. `--e2e`：空且无标记时 `showsOnboarding`；试一次后架子上有 `先读我.md`，且不再显示说明。
4. `--e2e`：不写 `opened`。
5. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
DROPAGENT_ROOT=/tmp/dropagent-preview-root macos/.build/debug/DropAgent --preview
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
```

## 假设与开放问题

无。
