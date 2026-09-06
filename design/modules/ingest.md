# 模块：Ingest

包：`DropAgentIngest`

## 做什么

把外面来的东西变成合法 `Item`，交给 `Shelf.add`。来源：文件 URL、剪贴板、当前页（转 Capture）。

## 不做什么

不决定跑 Recipe 还是 TUI（拖到 AI 区由 AppShell 二次调用 TUI）。不跑 Agent。不写 Jobs。

## Public

```text
admit(urls: [URL]) -> AdmitResult
admitClipboard() throws -> [Item]
admitPasteboard(_:) -> AdmitResult
admitProviders(_:) async -> AdmitResult
admitCurrentPage(token:) async throws -> Item
PageAdmit.freezeFrontBrowser / snapshot / decide / failure
```

失败：抛明确错误（空剪贴板、不支持的类型、抓页失败）。App 负责热键文案变体和系统设置跳转。部分成功：能进的进，失败的单独报，不整批回滚（用户连拖十个文件，九个进一个坏链，九个该留下）。空剪贴板粘贴抛错；空拖入板返回空结果、不报失败。

## 类型判定

| 输入 | kind | parts |
|------|------|--------|
| `.pdf` | pdf | 该文件 |
| png/jpg/webp/gif | image | 该文件 |
| `.md` / `.txt` | markdown | 该文件 |
| `.rtf` / `.rtfd` | file | 该文件（不做阅读器；剪贴板 RTF 仍是 CLIP） |
| `.html` / `.htm` | file | 该文件（不做阅读器） |
| 其他本地文件 | file | 该文件 |
| 文件夹 | folder | 目录本身（第一版按一个条目） |
| `http(s)` | url | 只有链接，不自动抓正文 |
| 剪贴板纯文本 | clip 或 url（若整段是 URL） | 写入 Application Support 下的 clip 文件 |
| 剪贴板图 | image | 写成 png |
| 当前页 | web | Capture 产出的 url.txt + page.md? + snapshot.png? |

文件复制进 DropAgent 自己的 `Inbox/` 再挂到 Item，避免源文件被用户立刻删掉导致条目空指。**Hash 仍对用户原路径做**（Job 模块）：Inbox 是工作副本，原件路径记在 `sourceURL`。

若原件在外置盘、已消失：admit 失败，不造空条目。

## 调用

`Shelf.add`；仅 `admitCurrentPage` → `Capture.captureFrontBrowser()`。授权门禁与前台冻结走 `PageAdmit`，不让 App 直接 import Capture。
