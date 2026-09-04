# 模块：Pasteboard

包：`DropAgentPasteboard`

## 做什么

按一条 Item 的 kind / parts，往系统 Pasteboard 填多种 UTI，供拖出和复制。默认复制：不从 Shelf 删除。

## 不做什么

不按「微信 / Cursor / Notion」产品名写分支。不写回原件。不一次拖多条（第一版）。不自动按目标 App 的发送按钮。

## Public

```text
export(item: Item) -> NSDraggingItem  // 或等价的 pasteboard writer
copy(item: Item)
promisedUTIs(for item: Item) -> [UTI]
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
