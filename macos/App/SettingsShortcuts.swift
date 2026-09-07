import SwiftUI

struct SettingsShortcuts: View {
    @ObservedObject var session: AppSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsForm.sectionTitle(Copy.t("快捷键", "Shortcuts"))
            Text(Copy.t(
                "点右边的键再按下新组合。全局快捷键必须带 ⌃ ⌥ ⇧ 或 ⌘。",
                "Click a shortcut, then press the new keys. Global shortcuts must include Control, Option, Shift, or Command."
            ))
            .font(.system(size: 11))
            .foregroundStyle(Palette.faint)
            SettingsForm.shortcutRow(session: session, slot: .toggle, title: Copy.t("打开 / 收起面板", "Show / Hide Panel"), caption: Copy.t("全局。被占用时点菜单栏图标。", "Global. If already in use, click the menu bar icon."))
            SettingsForm.shortcutRow(session: session, slot: .capture, title: Copy.t("抓取当前页", "Capture Current Page"), caption: Copy.t(
                "全局。Safari / Chrome / Edge 在最前时，把网址、正文和截图加入架子。",
                "Global. With Safari, Chrome, or Edge frontmost, adds the URL, body, and a screenshot."
            ))
            SettingsForm.shortcutRow(session: session, slot: .files, title: Copy.t("加入选中的文件", "Add Selected Files"), caption: Copy.t(
                "全局。Finder 读选中项；其他 App 先复制文件，没有文件再读当前打开的本地文件。浏览器请用抓页。",
                "Global. Finder uses the selection; other apps copy files first, then the open local file. Use page capture in a browser."
            ))
            SettingsForm.shortcutRow(session: session, slot: .hide, title: Copy.t("收起面板", "Hide Panel"), caption: Copy.t("面板开着时。输入时不触发。", "While the panel is open. Does not apply while typing."))
            SettingsForm.shortcutRow(session: session, slot: .paste, title: Copy.t("从剪贴板加入", "Paste onto Shelf"), caption: Copy.t("面板开着且没在输入时。", "While the panel is open and you are not typing."))
            SettingsForm.shortcutRow(session: session, slot: .copy, title: Copy.t("复制选中项", "Copy Selection"), caption: Copy.t("把架子上选中的条目复制到系统剪贴板。", "Copies the selected shelf item to the clipboard."))
            SettingsForm.shortcutRow(session: session, slot: .delete, title: Copy.t("隐藏选中项", "Hide Selection"), caption: Copy.t("从列表拿掉，不删文件。默认 ⌫ 和 ⌦ 都可以。改过之后只认你设的那一个。", "Removes the item from the list without deleting files. Default is Delete or Forward Delete. A custom shortcut uses only that key."))
            SettingsForm.guideLine(
                title: Copy.t("上一条 / 下一条", "Previous / Next Item"),
                keys: "↑  ↓",
                caption: Copy.t("只在面板里，不能改。", "Works in the panel only. Not customizable.")
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings-shortcuts")
    }
}
