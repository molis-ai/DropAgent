# 模块：Shelf

包：`DropAgentShelf`

## 做什么

架子上所有条目的唯一可变来源：增加、删掉、改状态、多选、按 id 查询、持久化 `shelf.json`。

## 不做什么

不读原件做 Hash。不启动 Agent。不抓网页。不写 Jobs 目录。不知道 Recipe 名字（只存 Job 回写的 `recipe` 字段）。

## Public

```text
add(_ item: Item) -> Item
remove(ids: [ItemID])
patch(id: ItemID, mutate: (inout Item) -> Void)
items() -> [Item]
item(id:) -> Item?
selection: Set<ItemID>
toggleSelect(id:, command: Bool)   // Command 多选；单击单选
persist() / load()
```

`Item` 是值类型。对外只给 snapshot。Job / TUI / Pasteboard 改状态必须走 `patch`。

## 状态机（条目）

```text
idle → confirm（点了 Recipe，等确认）
confirm → running | idle（取消）
running → done | failed
idle → sent（TUI 投递成功）
任意非 running → 可 remove
running 时禁止 remove 原件条目（可另开需求；第一版直接禁）
```

## 不变量

- 同一 `sourceURL`（规范化后）在架子上可以重复出现（用户连拖两次就是两条）。不在 Shelf 层去重。
- `parts` 为空不合法。网站条至少有 URL 这一 part。

## 调用谁

无。被 Ingest / Job / TUI / App 调用。
