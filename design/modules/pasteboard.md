# 模块：Pasteboard

包：`DropAgentPasteboard`

## 做什么

按一条 Item 的 kind / parts，往系统 Pasteboard 填多种 UTI，供拖出和复制。默认复制：不从 Shelf 删除。

另管最近 10 条剪贴板历史：系统剪贴板与本 App 复制过的，落在 `Clipboard/`，不去架子。点开只看；「放到架子」由 App 走 Ingest。隐蔽 / 自动生成 / 临时类型不记。文件只记路径。

## 不做什么

不按「微信 / Cursor / Notion」产品名写分支。不写回原件。多选时按选择里每条的文件一起交出；单条仍带该条的多种 UTI。不自动按目标 App 的发送按钮。

## Public

```text
export(item: Item) -> NSDraggingItem  // 或等价的 pasteboard writer
copy(item: Item)
promisedUTIs(for item: Item) -> [UTI]
ClipHistoryStore.record / remove / records
itemProvider(forClip:imageURL:)
```

## 形态表（与需求第 11 节一致）

| kind | 必带 | 尽量带 |
|------|------|--------|
| pdf / folder / 文件 | file URL | — |
| markdown / clip / 总结产出 | file URL + utf8 text | — |
| image | file URL + png | — |
| url | public.url + 文本 URL | — |
| web | 文件夹（url + 有则 md + 有则 png） | 文本优先 md；图目标给 png |

接不住：系统弹回，本模块不弹自定义错窗。

## 调用谁

只读 Item 值。不调用 Shelf.remove。
