# 模块：Shelf

包：`DropAgentShelf`

## 做什么

架子上所有条目的唯一可变来源：增加、删掉、改状态、多选、按 id 查询、持久化 `shelf.json`。Job 产出是 `ResultRecord`，存在同一文件的 `results`，不出现在左列 `items()`。

## 不做什么

不读原件做 Hash。不启动 Agent。不抓网页。不写 Jobs 目录。不知道 Recipe 名字（只存 Job 回写的 `recipe` 字段）。

## Public

```text
add(_ item: Item) -> Item
addResult(_ record: ResultRecord) -> ResultRecord
remove(ids: [ItemID])
removeResults(ids: [ResultID])
patch(id: ItemID, mutate: (inout Item) -> Void)
items() -> [Item]
results() -> [ResultRecord]
item(id:) -> Item?
result(id:) -> ResultRecord?
selection: Set<ItemID>
toggleSelect(id:, command: Bool)   // Command 多选；单击单选；已选再点清空
persist() / load()
```

`Item` 是值类型。对外只给 snapshot。Job / TUI 改条目走 `patch`；产出走 `addResult`。

## 状态机（条目）

```text
idle → confirm（点了 Recipe，等确认）
confirm → running | idle（取消）
running → idle（成功或失败都回到 idle；产出进 results）
idle → sent（TUI 投递成功）
任意非 running → 可 remove（隐藏：只改 shelf.json）
running 时禁止 remove 原件条目
删磁盘不在 Shelf：输入走 Ingest.deleteOwnedCopy，结果走 Job.deleteOwnedOutput
```

旧 `shelf.json` 里已经是 `done` 的行仍按旧状态机展示。新 Job 不再把输入写成 done。

## 不变量

- 同一 `sourceURL`（规范化后）在架子上可以重复出现（用户连拖两次就是两条）。不在 Shelf 层去重。
- `parts` 为空不合法。网站条至少有 URL 这一 part。

## 调用谁

无。被 Ingest / Job / TUI / App 调用。
