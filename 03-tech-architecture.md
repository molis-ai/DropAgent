# DropAgent 总技术方案

状态：总方案。产品事实以 `01-requirements.md`、`02-prototype-design.md` 为准。  
本文管：怎么拆包、谁调用谁、数据放哪、第一版做到哪。不管 Prompt 正文、不管营销文案。

各模块细案在 `design/modules/`。实现必须能对上本文的调用链；对不上先改方案再改代码。

---

## 1. 要做成什么样

Mac 菜单栏小工具。上面是文件架，下面是结果区；点「其他」才出对话区。东西先进来，可以先放着；要么用当前芯片对应的 CLI 在副本里跑 Recipe，要么把材料和一句话打进当前所选 TUI。结果在工具里能看，再拖走或复制。原件不被覆盖。

两套代码、同一套边界：

| 层 | 路径 | 职责 |
|----|------|------|
| 产品内核 | `macos/Packages/` | 无 UI 的纯逻辑：架子、进货、任务、探测 Agent、剪贴板形态、抓网页。可单测。 |
| 菜单栏壳 | `macos/App/` | 状态栏、面板、拖入命中、快捷键、内嵌 PTY 视图。只通过内核 public API。 |
| 设计原型 | `prototype/` | 同一套模块名和状态机的 HTML，用来打磨交互。禁止在原型里发明内核没有的业务规则。 |

第一版分发：Developer ID，不上 Mac App Store。

---

## 2. 分包（不可协商）

禁止再出现一个「什么都干」的 `Utils` / `Common` / `Helper`。跨模块只走对方的 public 接口。

```text
macos/
  App/                      壳：菜单栏、窗口、快捷键注册。不许写 Job / Hash / 抓页。
  Packages/
    DropAgentShelf/        架子：条目、选择、状态。唯一持有 Item 列表。
    DropAgentIngest/       进货：拖入解析、剪贴板、当前页抓取。只调用 Shelf.add。
    DropAgentJob/          副本任务：Jobs/<id>、Recipe、Hash、事件日志。
    DropAgentAgent/        探测本机 Agent、隔离档位文案。不跑 UI、不持有架子。
    DropAgentTUI/          把材料和用户那句话送进对应 TUI 会话。不解析屏幕。
    DropAgentPasteboard/   拖出 / 复制：按条目组装系统剪贴板。另管最近 10 条剪贴板历史（落盘、不去架子）。别处复制的本地文件由 App 盯板后走 Ingest，不进这段历史。
    DropAgentCapture/      读前台浏览器 URL+标题，或按已有 URL 抓正文 md、截图。被 Ingest 调用。
```

依赖方向（箭头表示「允许依赖」）：

```text
App
  → Shelf, Ingest, Job, Agent, TUI, Pasteboard

Ingest → Shelf, Capture
Job    → Shelf, Agent
TUI    → Shelf, Agent
Capture → （系统 API / 网络）。禁止依赖 Shelf / Job / TUI
Agent  → 无业务依赖
Pasteboard → 只读 Item 快照（值类型），不依赖 Shelf 单例
Shelf  → 无业务依赖
```

App 不 import Capture。抓页快捷键经 `Ingest.PageAdmit` 冻结前台、做授权门禁，再 `admitCurrentPage`。就绪卡 / 设置「使用准备」经 `PageAdmit.setupStatus` / `requestAutomation` 探测和要权，不是第五条链。`App` 是唯一装配点。测试可以直接 new 内核模块，不必启动菜单栏。

---

## 3. 调用链

所有用户动作最终只有四条链。新功能必须挂在其中一条上，禁止另开暗道。

```text
A. 进货
   拖入 / 粘贴快捷键 / 抓页快捷键 / 加入选中文件快捷键
     → Ingest.admit(payload)
     → Capture?（架子上的 http(s) 走 captureURL；热键走 captureFrontBrowser）
     → Shelf.add(item)（链接先 stub 再 patch）
     → 面板刷新

B. 副本 Recipe
   选 Recipe → 确认
     → Job.start(itemIDs, recipe)
     → 复制到 Jobs/<id>/{input,work}
     → CLI Recipe：Agent.run(workdir: work/, isolation)
       文字提取：图片用 Vision；PDF 用 PDFKit 抽 work/ 里的内嵌文字
     → 写 output/ → Hash 校验原件
     → Shelf.patch(id, .done, output)
     → 面板切到「结果」

C. 发给 TUI
   发送 / 轮盘「发给」
     → TUI.send(itemIDs, text)
     → Agent.ensureSession()（没有就拉起）
     → 把副本路径和文本打进会话
     → Shelf.patch(id, .sent)
     → 面板切到「终端」

D. 拿走
   拖出行 / 复制
     → Pasteboard.export(item) 或 copy(item)
     → 系统 Pasteboard；架子默认仍保留该条
```

禁止：

- Ingest 直接调 Job 或 TUI（「放下就跑」不是默认；轮盘「发给」由 App 判给 C，不是 Ingest 自己跑。拖进面板走 A）。
- Job 写原路径；Pasteboard 改 Item 状态为删除（第一版是复制）。
- TUI 去 OCR 终端画面。
- Shelf 自己访问磁盘上的原件路径去做 Hash（Hash 只在 Job 里）。

---

## 4. 核心数据

### 4.1 Item（架子上的一条）

值类型。Shelf 是唯一可变来源。别的模块拿 snapshot，不持有引用乱改。

| 字段 | 含义 |
|------|------|
| id | 稳定 ID |
| kind | pdf / image / url / markdown / clip / web / folder / file |
| title | 展示名 |
| sourceURL | 原件路径或网页 URL（给 Job 做快照和 Hash；不写进 Prompt） |
| parts | 该条包含的文件（网站：url.txt + page.md + snapshot.png） |
| status | idle / confirm / running / done / sent / failed |
| recipe | 可选 |
| output | 完成后主交付路径 |
| isolationShown | 当前对外说的档：workspace / unconfirmed / safeCopy / tui / none |

### 4.2 Job 目录

```text
~/Library/Application Support/DropAgent/Jobs/<id>/
  input/          快照，只读
  work/           Agent 工作目录
  output/         只从这里回到架子
  manifest.json
  events.jsonl
```

原件：复制，不用符号链接。Prompt 里只用 `work/` 内相对路径。

### 4.3 持久化

Shelf 列表存 Application Support 下的 `shelf.json`。不进 iCloud、不做多设备同步（第一版）。

剪贴板历史存 `Clipboard/history.json` 与图片 blob。最多 10 条。不是架子 Item，进货仍走 Ingest。别处复制的本地文件直接 `Ingest.admit(urls:)`，不写进这段历史。

---

## 5. 模块职责一句话

| 模块 | 做什么 | 不做什么 |
|------|--------|----------|
| App | 窗口、拖入命中（文件行 / 对话区 / 图标）、快捷键、拼 UI | 业务规则 |
| Shelf | 增删改、多选、查询 | 跑 Agent、抓网页 |
| Ingest | 把外部东西变成 Item | 决定跑 Recipe 还是 TUI |
| Capture | URL+标题、md、截图 | 加入架子 |
| Job | 副本、Recipe、Hash、事件；图片文字提取用 Vision，PDF 抽字用 PDFKit | 画 UI、发 TUI |
| Agent | 发现二进制、档位文案、执行配置 | 选 Recipe |
| TUI | 投递进已有或新拉起的会话 | 解析 TUI 画面 |
| Pasteboard | 按 kind 填多种 UTI；记下最近剪贴板 | 删除架子条目、改系统当前剪贴板 |

细案见：

- `design/modules/app-shell.md`
- `design/modules/shelf.md`
- `design/modules/ingest.md`
- `design/modules/capture.md`
- `design/modules/job.md`
- `design/modules/agent.md`
- `design/modules/tui.md`
- `design/modules/pasteboard.md`
- `design/modules/ai-pane.md`（UI 状态，属于 App 的一块，规则仍来自 Job/TUI）

---

## 6. 进货判定（App 的唯一分拣）

| 落点 | 调用 |
|------|------|
| 菜单栏图标 | `Ingest.admit` → 只进架子（http(s) 随后抓页） |
| 鼠标旁拖放轮盘 | 同上 |
| 面板文件行 | 同上 |
| 对话区 | `Ingest.admit(..., capturePages: false)` 得到 Item，立刻 `TUI.send`（框里有字带上） |
| 粘贴快捷键（默认 ⌘V） | `Ingest.admitClipboard`；http(s) 随后 `captureDroppedPages` |
| 别处复制的本地文件 | 盯系统剪贴板 → `ClipboardStaging.filesToAdmit` → `Ingest.admit(urls:)`；本 App 复制的 Inbox / Jobs 文件只记历史 |
| 抓页快捷键 | `Ingest.admitCurrentPage` |
| 加入选中文件快捷键 | `FrontAdmit.collect` → `Ingest.admit(urls:)` |

没有 Agent 时：对话区落点仍 `admit` 进架子，并提示不能发送；不假装跑成功。

---

## 7. Agent 与安全

探测顺序：`PATH` 与常见安装路径上的预置二进制 → 用户在设置里指定或添加的 Runtime。TUI 与 Recipe 都跟芯片，默认 `auto`（Grok → Claude → Gemini → OpenCode → Cursor CLI → Codex → Kimi Code → CodeBuddy → Qwen Code）。文件名 `agent` 用 `--help` 区分 Grok 与 Cursor CLI，不要把 `~/.grok/bin/agent` 认成 Cursor。Recipe 只使用该 CLI `--help` 能证明的无界面 / 可收口入口；没有入口就禁用动作，不许解析 TUI、不许模拟按键。自定义纯 CLI 发送走面板里的默认 shell 命令，不打开 Terminal.app。

| 路径 | 对外文案 | 实现要点 |
|------|---------|----------|
| Recipe | Workspace（该 CLI 官方工作区限制，探测到才这么写） | 芯片对应 CLI 的官方无界面入口，cwd=`work/`，不加载用户全局 MCP/Hooks |
| 文字提取 | 本机识别 / 抽字，不发送 | 图片：Vision 写 `ocr.md`。PDF：PDFKit 写 `pdf.md`。都不调 CLI |
| 发给 TUI | 「在终端执行，不是副本沙箱」 | 把**副本**路径和文本送进所选 TUI（Grok / Claude / Gemini / OpenCode / Cursor CLI / Codex / Kimi Code / CodeBuddy / Qwen Code）；自定义纯 CLI 则在默认 shell 里发出译好的命令。仍不把原件路径塞进会话；隔离 home，不加载用户 MCP/Hooks |
| 无 TUI | 未发现终端 Agent | 禁止 send；CLI Recipe 禁止 Job.start；文字提取仍可跑 |
| 芯片 CLI 无执行入口 | 说明该 CLI 没有无界面执行入口 | CLI Recipe 禁止 Job.start；有 TUI 时仍可发送；文字提取仍可跑 |

Recipe 跑完：对 `sourceURL` 若是本地文件，再读一遍 Hash，必须与 admit 时一致。

抓网页：DropAgent 自己联网，UI 不把它说成 Workspace。失败策略见 Capture 模块。

---

## 8. 拖出形态（Pasteboard）

由 `DropAgentPasteboard` 按 Item.kind 填写，不按目标 App 名称分支。

| 条目 | 始终尽量带上 |
|------|----------------|
| 文件类 | `public.file-url`（真实文件） |
| 文稿 / 总结 | 另加 `public.utf8-plain-text` |
| 图 | `public.png` 或 TIFF |
| URL | `public.url` |
| 网站组合 | 文件夹（链接 + md + 截图）；文本优先 md；图目标给截图 |

多选时一次拖出所选项。默认复制。接不住由系统弹回。

---

## 9. 第一版实施顺序

工程原型（真跑通）先于六 Recipe 全开、先于 Claude/Gemini：

1. Shelf + Ingest 拖入文件 + 面板列表  
2. Job：仅「总结文件」+ Codex + Hash  
3. Pasteboard 拖到 Finder  
4. TUI.send 最小闭环（能把文件和一句话送进 Codex 会话）  
5. 剪贴板进出  
6. Capture 快捷键（Safari/Chrome）  
7. 其余 Recipe  
8. 拖放轮盘、多选 Recipe、网站组合拖出文件夹  

设计原型 `prototype/` 与上述状态机对齐，用 Impeccable 打磨；不替代 1–4 的本机验收。

---

## 10. 测试与验收

内核每个模块：单元测试（Item 状态迁移、Hash、Pasteboard UTI 集合、Capture 失败降级）。

端到端（本机）：

1. 拖 PDF 进列表，不跑 Agent。  
2. 总结后原件 Hash 不变，`output/summary.md` 可拖到桌面。  
3. 无 TUI 时发送禁用、进货仍可；芯片对应 CLI 不能跑 Job 时 Recipe 禁用，有 TUI 仍可发送。  
4. 快捷键在 Safari 有地址时出现 WEB 条；读失败有明确失败，不造假条目。

---

## 11. 扩展怎么加

- 新进货源：只加 Ingest 的一个 admit* ，产出 Item。  
- 新 Agent：只加 Agent 的一个 Adapter，Job/TUI 不改签名。  
- 新 Recipe：只加 Job 的 Recipe 声明（输入输出 + 权限），不开放任意 Shell。  
- 新 UI：只加 App，不把规则写进 View。

---

## 12. 本文不管什么

- 六个 Recipe 的 Prompt 全文  
- 具体快捷键组合  
- MAS 沙箱方案  
- 多设备同步

### 文件工作台装配（2026-09-12）

`PanelRootView` 拼 `WorkbenchSidebar` / `WorkbenchDetail`，后者挂 `ContentStage`、确认状态、常驻 `RecipeChooser` 与保持实例的 `AIPane`。`AppSession+Workbench` 持有剪贴板焦点与入架、结果对照；历史不是 Item，调用 `Ingest.admitPayload` 后才成为材料。`PaneFocus` 区分 input / result / clipboard，键盘、复制、删除、运行和发送门禁都按焦点处理。
