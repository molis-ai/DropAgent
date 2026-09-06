# 抓页正文要像 Markdown，不是去标签

## 背景目标

`01` / `02` 要求抓页交出 `page.md`。现在 `HTMLMarkdown.convert` 只剥标签，导航和正文混在一起，链接变成裸字。

## 当前行为与问题证据

Check 已覆盖 article / 链接。2026-09-06 真抓 `https://example.com/` 的 `page.md` 开头是：

```
Example Domain
-
# Example Domain
```

页上没有列表。HTML 是 `<link rel="icon" href="data:,">`。`<(li)[^>]*>` 把 `<link` 当成 `<li>`，写成 Markdown 的 `-`。同类：`<p>` 会吃到 `<pre>`，`<b>` / `<i>` 会吃到 `<body>` / `<img>`。

## 范围

- 有 `<article>` 或 `<main>` 时只用这一块，丢掉导航。
- `<a href>` 转成 `[字](url)`；相对地址按当前页 URL 补成绝对 `http(s)`；`javascript:` / `data:` 只留字。
- `<strong>` / `<b>`、`<em>` / `<i>` 转成 Markdown 强调。
- 替换 HTML 标签时用词边界，`<link>` / `<pre>` / `<body>` 不能当成 `<li>` / `<p>` / `<b>`。
- 丢掉 `<head>`（页面标题已在条目名里，不进 `page.md`）。
- 继续去 script/style；标题、列表、段落仍在。
- 解码常见实体和数字实体。
- 不装扩展、不带登录 Cookie。

## 非目标

- 不做完整 HTML 解析器、不抓整站。
- Developer ID。

## 验收

1. Check：带 nav + article 的页，正文在、导航不在。
2. Check：链接变成 Markdown 链接，`&mdash;` 变成 —。相对 `/x` 在 `https://example.com/page` 上变成 `https://example.com/x`。
3. Check：原有 h1 / 实体 / 去 script 仍过。
4. Check：example.com 形状的 HTML（title + `<link>` + h1 + 段落）不得出现单独一行 `-`，也不把 `<title>` 再抄进正文；真 `<li>` 仍是 `- One`。
5. Check 全绿。

## 验证命令

```bash
cd macos && swift run DropAgentCheck
```
