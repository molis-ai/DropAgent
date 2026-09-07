import SwiftUI

struct SettingsPane: View {
    @ObservedObject var session: AppSession

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(Copy.t("设置", "Settings"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Button(action: { session.settingsOpen = false }) {
                    Text(Copy.t("完成", "Done"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.text)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Palette.panel2)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings-done")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    setupSection
                    shortcutSection
                    guideSection
                    workspaceSection
                    runtimeSection
                    appearanceSection
                    languageSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.panel)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Copy.t("设置", "Settings"))
        .accessibilityIdentifier("settings-pane")
        .onAppear { session.beginSetupWatch() }
        .onDisappear { session.endSetupWatch() }
    }

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(SetupCopy.title)
            SetupChecklist(session: session)
        }
        .accessibilityIdentifier("settings-setup")
    }

    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(Copy.t("快捷键", "Shortcuts"))
            Text(Copy.t(
                "点右边的键再按下新组合。全局快捷键必须带 ⌃ ⌥ ⇧ 或 ⌘。",
                "Click the key then press a new combo. Global shortcuts need ⌃ ⌥ ⇧ or ⌘."
            ))
            .font(.system(size: 11))
            .foregroundStyle(Palette.faint)
            shortcutRow(
                slot: .toggle,
                title: Copy.t("打开 / 收起面板", "Open / hide panel"),
                caption: Copy.t("全局。被占用时点菜单栏图标。", "Global. If taken, click the menu bar icon.")
            )
            shortcutRow(
                slot: .capture,
                title: Copy.t("抓取当前页", "Capture current page"),
                caption: Copy.t(
                    "全局。Safari / Chrome / Edge 在最前时，把网址、正文和截图加入架子。",
                    "Global. With Safari / Chrome / Edge frontmost, adds URL, body, and screenshot."
                )
            )
            shortcutRow(
                slot: .files,
                title: Copy.t("加入选中的文件", "Add selected files"),
                caption: Copy.t(
                    "全局。Finder 读选中项；其他 App 先复制文件，没有文件再读当前打开的本地文件。浏览器请用抓页。",
                    "Global. Finder uses the selection; other apps copy files first, then the open local file. Use page capture in a browser."
                )
            )
            shortcutRow(
                slot: .hide,
                title: Copy.t("收起面板", "Hide panel"),
                caption: Copy.t("面板开着时。输入时不触发。", "While the panel is open. Ignored while typing.")
            )
            shortcutRow(
                slot: .paste,
                title: Copy.t("从剪贴板加入", "Paste onto the shelf"),
                caption: Copy.t("面板开着且没在输入时。", "While the panel is open and you are not typing.")
            )
            shortcutRow(
                slot: .copy,
                title: Copy.t("复制选中项", "Copy selection"),
                caption: Copy.t("把架子上选中的条目复制到系统剪贴板。", "Copies the selected shelf item to the pasteboard.")
            )
            shortcutRow(
                slot: .delete,
                title: Copy.t("从架子移除", "Remove from shelf"),
                caption: Copy.t("默认 ⌫ 和 ⌦ 都可以。改过之后只认你设的那一个。", "Default is both ⌫ and ⌦. A custom key uses only that key.")
            )
            guideLine(
                title: Copy.t("上一条 / 下一条", "Previous / next item"),
                keys: "↑  ↓",
                caption: Copy.t("只在面板里，不能改。", "Panel only, not customizable.")
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings-shortcuts")
    }

    private var guideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(Copy.t("能做什么", "What it can do"))
            guideCard(title: SettingsGuideCopy.dropInTitle, body: SettingsGuideCopy.dropIn)
            guideCard(title: SettingsGuideCopy.filesTitle, body: SettingsGuideCopy.files)
            guideCard(title: SettingsGuideCopy.acceptsTitle, body: SettingsGuideCopy.accepts)
            guideCard(title: SettingsGuideCopy.browserTitle, body: SettingsGuideCopy.browser)
            guideCard(title: SettingsGuideCopy.readsTitle, body: SettingsGuideCopy.reads)
            guideCard(title: SettingsGuideCopy.writesTitle, body: SettingsGuideCopy.writes)
            guideCard(title: SettingsGuideCopy.dropOutTitle, body: SettingsGuideCopy.dropOut)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings-guide")
    }

    private var workspaceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(Copy.t("默认工作区", "Workspace"))
            pathRow(
                title: Copy.t("写入区域", "Incoming files"),
                caption: Copy.t(
                    "拖进来的文件副本放在这里。原件不动。",
                    "Staged copies of dropped files live here. Originals stay put."
                ),
                path: DropAgentPaths.inbox,
                isOverride: session.prefs.inboxPath != nil,
                choose: { session.pickWorkspaceFolder(.inbox) },
                reset: { session.setWorkspaceFolder(.inbox, url: nil) }
            )
            pathRow(
                title: Copy.t("输出结果", "Results"),
                caption: Copy.t(
                    "Recipe 跑完的新文件放在这里，目录是任务编号 / output。",
                    "New files from recipes land here, under each job id / output."
                ),
                path: DropAgentPaths.jobs,
                isOverride: session.prefs.jobsPath != nil,
                choose: { session.pickWorkspaceFolder(.jobs) },
                reset: { session.setWorkspaceFolder(.jobs, url: nil) }
            )
        }
    }

    private var runtimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(Copy.t("Runtime", "Runtime"))
            Text(Copy.t(
                "有画面的进内嵌终端。纯 CLI 会在默认 shell 里发出一条普通命令。",
                "TUI tools open in the panel terminal. Plain CLIs are sent as a normal shell command."
            ))
            .font(.system(size: 11))
            .foregroundStyle(Palette.faint)
            ForEach(session.settings.customRuntimes) { custom in
                VStack(alignment: .leading, spacing: 6) {
                    Text(custom.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.text)
                    Text(custom.executable)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                        .textSelection(.enabled)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        Button(action: { session.setCustomRuntimeKind(custom.id, kind: .tui) }) {
                            Text("TUI")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(QuietButtonStyle())
                        .opacity(custom.kind == .tui ? 1 : 0.55)
                        Button(action: { session.setCustomRuntimeKind(custom.id, kind: .cli) }) {
                            Text("CLI")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(QuietButtonStyle())
                        .opacity(custom.kind == .cli ? 1 : 0.55)
                        Button(action: { session.removeCustomRuntime(custom.id) }) {
                            Text(Copy.t("删除", "Remove"))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(QuietButtonStyle())
                    }
                    .frame(height: 30)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.panel2.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line))
            }
            Button(action: { session.pickTUIExecutable() }) {
                Text(Copy.t("添加 Runtime…", "Add Runtime…"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(QuietButtonStyle())
            .frame(height: 32)
            .accessibilityIdentifier("settings-add-runtime")
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(Copy.t("颜色", "Appearance"))
            segmented(
                items: [
                    (AppearancePreference.light, Copy.t("浅色", "Light")),
                    (.dark, Copy.t("深色", "Dark")),
                    (.system, Copy.t("跟随系统", "System")),
                ],
                selected: session.prefs.appearance
            ) { session.setAppearance($0) }
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(Copy.t("语言", "Language"))
            segmented(
                items: [
                    (AppLanguage.zh, "中文"),
                    (.en, "English"),
                    (.system, Copy.t("跟随系统", "System")),
                ],
                selected: session.prefs.language
            ) { session.setLanguage($0) }
        }
    }

    private func shortcutRow(slot: HotKeySlot, title: String, caption: String) -> some View {
        let recording = session.recordingHotKey == slot
        let chord = session.chord(for: slot)
        let taken = (slot == .toggle && session.hotKeyToggleOK == false)
            || (slot == .capture && session.hotKeyCaptureOK == false)
            || (slot == .files && session.hotKeyFilesOK == false)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.text)
                        .textSelection(.enabled)
                    Text(taken ? Copy.t("这个组合被占用。", "This combo is taken.") : caption)
                        .font(.system(size: 11))
                        .foregroundStyle(taken ? Palette.muted : Palette.faint)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 8)
                Button(action: {
                    if recording {
                        session.cancelRecording()
                    } else {
                        session.beginRecording(slot)
                    }
                }) {
                    Text(recording ? Copy.t("按下…", "Press…") : chord.label)
                        .font(.system(size: 12, weight: .semibold).monospaced())
                        .foregroundStyle(Palette.text)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(recording ? Palette.panelPress : Palette.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("shortcut-\(slot.rawValue)")
                if chord != slot.defaultChord {
                    Button(action: { session.resetHotKey(slot) }) {
                        Text(Copy.t("默认", "Default"))
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.muted)
                            .padding(.horizontal, 8)
                            .frame(height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.panel2.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line))
    }

    private func guideLine(title: String, keys: String, caption: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.text)
                Text(caption)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.faint)
            }
            Spacer(minLength: 8)
            Text(keys)
                .font(.system(size: 12, weight: .semibold).monospaced())
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Palette.panel)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.panel2.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line))
    }

    private func guideCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.text)
                .textSelection(.enabled)
            Text(body)
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.panel2.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Palette.muted)
            .textSelection(.enabled)
    }

    private func pathRow(
        title: String,
        caption: String,
        path: URL,
        isOverride: Bool,
        choose: @escaping () -> Void,
        reset: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.text)
            Text(Copy.displayPath(path))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Palette.muted)
                .textSelection(.enabled)
                .lineLimit(2)
            Text(caption)
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
            HStack(spacing: 8) {
                Button(action: choose) {
                    Text(Copy.t("选择文件夹…", "Choose Folder…"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(QuietButtonStyle())
                if isOverride {
                    Button(action: reset) {
                        Text(Copy.t("恢复默认", "Reset"))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(QuietButtonStyle())
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.panel2.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Palette.line)
        )
    }

    private func segmented<Value: Equatable>(
        items: [(Value, String)],
        selected: Value,
        onPick: @escaping (Value) -> Void
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                let on = item.0 == selected
                Text(item.1)
                    .font(.system(size: 12, weight: on ? .semibold : .regular))
                    .foregroundStyle(Palette.text)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(on ? Palette.panel : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                    .onTapGesture { onPick(item.0) }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .accessibilityLabel(item.1)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .padding(2)
                if index < items.count - 1 {
                    Divider().overlay(Palette.line)
                        .frame(height: 16)
                }
            }
        }
        .background(Palette.panel2)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Palette.line)
        )
    }
}

enum SettingsGuideCopy {
    static var dropInTitle: String { Copy.t("拖进去", "Drop in") }
    static var dropIn: String {
        Copy.t(
            "菜单栏图标、屏幕顶边黑条、左侧列表：加入架子（复制进写入区域，原件不动）。右侧 AI：发给当前终端。顶边进货不会自动打开或关掉面板。",
            "Menu bar icon, the top edge bar, and the left list add to the shelf (a copy in the incoming folder; originals stay put). The right AI pane sends to the current terminal. Dropping on the top edge does not open or close the panel."
        )
    }

    static var filesTitle: String { Copy.t("选中的文件", "Selected files") }
    static var files: String {
        Copy.t(
            "「加入选中的文件」：Finder / 桌面读选中项（可多选）。VSCode 等先模拟 ⌘C，只收文件，剪贴板会还原；没有文件再读当前打开的本地文件。浏览器最前请用抓页。原件不动。",
            "Add selected files: Finder / Desktop uses the selection (multiple ok). VS Code and similar first simulate ⌘C and keep only files, then restore the clipboard; if none, the open local file is used. In a browser, use page capture. Originals stay put."
        )
    }

    static var acceptsTitle: String { Copy.t("能接什么", "What it accepts") }
    static var accepts: String {
        Copy.t(
            "文件、文件夹、PDF、图片（PNG / JPG / GIF / WebP / HEIC）、文本 / Markdown、链接。+ 选文件，或搜索桌面 / 文稿 / 下载。剪贴板可粘贴。",
            "Files, folders, PDFs, images (PNG / JPG / GIF / WebP / HEIC), text / Markdown, and links. Use + to pick files, or search Desktop / Documents / Downloads. Paste from the clipboard."
        )
    }

    static var browserTitle: String { Copy.t("浏览器", "Browser") }
    static var browser: String {
        Copy.t(
            "拖到菜单栏图标、顶边条、左侧列表，或粘贴整段网址：架子上先出现网站条，后台抓正文和截图（按该地址取页，不截你眼前的窗口；登录墙往往只留下链接）。拖到右侧 AI 区只把链接送进终端，不抓页。当前窗口整页（含窗口截图）仍用「抓取当前页」快捷键，Safari / Chrome / Edge 要在最前。Safari 标签若系统不交 URL，仍进不来。",
            "Drop on the menu bar icon, top edge, left list, or paste a URL: the shelf gets a website item and fetches the body and a page snapshot in the background (from that URL, not the front window; logged-in pages often keep only the link). Drop on the right AI pane sends the link to the terminal and does not fetch. A full front-window page still uses the capture shortcut while Safari / Chrome / Edge is frontmost. Safari tabs still cannot be dropped if the system gives no URL."
        )
    }

    static var readsTitle: String { Copy.t("读什么", "What it reads") }
    static var reads: String {
        Copy.t(
            "抓页会读前台浏览器的地址、标题、正文和窗口截图，需要辅助功能和自动化授权。Recipe 只读任务副本，Prompt 里不写原件路径，也不加载你的全局 MCP / Hooks。",
            "Capture reads the front browser’s URL, title, body, and a window screenshot. Accessibility and Automation permission are required. Recipes read the job copy only; prompts never include original paths, and your global MCP / Hooks are not loaded."
        )
    }

    static var writesTitle: String { Copy.t("写什么", "What it writes") }
    static var writes: String {
        Copy.t(
            "拖入的副本写在「写入区域」（默认 Inbox）。Recipe 结果写在「输出结果」下的任务编号 / output。不覆盖原文件。终端发送走那个 Agent 自己的权限，不是副本沙箱。",
            "Dropped copies go to Incoming files (Inbox by default). Recipe results go under Results / job-id / output. Originals are never overwritten. Sending to a terminal uses that agent’s own permissions, not the copy sandbox."
        )
    }

    static var dropOutTitle: String { Copy.t("拖出去", "Drop out") }
    static var dropOut: String {
        Copy.t(
            "一次拖一条，复制不是挪走。Finder / 桌面、上传框、多数聊天和编辑器能接文件或文字。网站抓取拖出是文件夹：链接、正文 md、截图。接不住就弹回架子。",
            "One item at a time, copy not move. Finder / Desktop, upload fields, and most chats or editors can take a file or text. A captured page drags out as a folder: link, markdown, screenshot. If the target refuses, it springs back."
        )
    }
}
