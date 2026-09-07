# 菜单栏图标：朝下实心漏斗落到搁板

## 背景与目标

菜单栏 18 点图标和 App 图标本是同一套「漏斗落到搁板」，但 `StatusIcon.draw()` 在 y 轴翻转后仍按 AppKit 底为原点写坐标，结果尖朝上、搁板在顶上。空心 1.5pt 描边在菜单栏里也太瘦。改成朝下的实心圆角漏斗 + 圆角搁板，仍是模板图。

## 当前行为与问题证据

- `StatusIcon.draw()`：三角 `(3, 11.5) → (15, 11.5) → (9, 4.8)`，搁板 `y = 3.2`。绘制上下文先把 `rep.size` 设成 18pt 再按像素数翻转坐标系，实心填充几乎画在画布外，空心描边只剩残片，看起来像尖朝上。
- `make-icon.swift` 的 App 图标是朝下漏斗 + 底下一根搁板，两边不一致。
- `specs/menu-extra-craft/spec.md` 要求朝下描边三角；本 spec 替换其中的形状，尺寸 / 模板 / 1x+2x 仍有效。

## 范围与非目标

- 改 `StatusIcon.draw()`：朝下实心漏斗（圆角）、底下一根圆角搁板；黑填充，`isTemplate == true`。
- e2e：除原有尺寸/模板/倍率外，抽像素确认漏斗在上半、搁板在底部、顶部留白（防止再画反）。
- 不改 `make-icon.swift` App 图标（深底白描边可留）。
- 不改面板、热键、投放、调用链。

## 方案

同一套 Drop 语言，菜单栏用实心是因为 18 点旁是控制中心一类实心符号。漏斗路径描边 + 填充得到圆角，和 App 图标的 round join 同族。位图先按像素画（AppKit y 向上、只 `scale` 倍率），画完再把 `rep.size` 设成 18pt，避免再翻 y。e2e 读 `bitmapData` 的 alpha，不走 `colorAt`。

## 文件边界

- `macos/App/AppDelegate.swift`（`StatusIcon`）
- `macos/App/AppE2E.swift`（像素抽查）
- `specs/menu-extra-craft/spec.md`（形状让位本 spec）

## 验收

1. 菜单栏图标朝下：实心漏斗在上、搁板在下，浅色/深色菜单栏都清楚。
2. `StatusIcon.image()` 仍 18×18、1x+2x、`isTemplate == true`。
3. e2e 像素：漏斗内部不透明、画布顶部透明、搁板不透明。
4. Check 全绿；`swift build --product DropAgent` 通过。
5. 打包 App 菜单栏目视与 B 方案一致。

## 验证

```bash
cd macos && swift run DropAgentCheck
cd macos && swift build --product DropAgent
DROPAGENT_ROOT=/tmp/dropagent-e2e-live macos/.build/debug/DropAgent --e2e
bash macos/package-app.sh
```
