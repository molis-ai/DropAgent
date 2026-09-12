import AppKit
import DropAgentPasteboard
import DropAgentShelf
import SwiftUI

struct WorkbenchSidebar: View {
    @ObservedObject var session: AppSession
    @State private var allClips = false
    @State private var expandedFolders: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            searchBar.padding(.horizontal, 10).padding(.top, 12).padding(.bottom, 6)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        directoryHeader(
                            Copy.t("材料", "Materials"),
                            systemImage: "folder",
                            tone: .ochre,
                            count: listingQuery ? session.visibleItems.count : session.items.count,
                            expanded: session.materialsExpanded || listingQuery,
                            identifier: "materials-toggle"
                        ) { session.materialsExpanded.toggle() }
                        if session.materialsExpanded || listingQuery {
                            if session.items.isEmpty {
                                emptyLine(Copy.t("拖入文件，或粘贴文字与链接", "Drop files, or paste text and links"))
                            } else if session.visibleItems.isEmpty {
                                emptyLine(Copy.t("没有叫这个名字的材料", "No materials match this search"))
                            }
                            ForEach(session.visibleItems, id: \.id) { item in
                                fileRow(item).id("material-" + item.id.rawValue)
                                if item.kind == .folder, session.paneFocus == .input, session.selectedItems.first?.id == item.id {
                                    FolderTreeRows(
                                        url: item.parts.first?.url ?? item.sourceURL,
                                        root: item.parts.first?.url ?? item.sourceURL,
                                        depth: 0,
                                        selected: $session.folderPreviewURL,
                                        expanded: $expandedFolders
                                    )
                                    .padding(.leading, 12 + WorkbenchSidebarLayout.fileIndent)
                                }
                            }
                        }
                        if !session.results.isEmpty {
                            directoryHeader(
                                Copy.t("生成结果", "Results"),
                                systemImage: "doc.text",
                                tone: .slate,
                                count: listingQuery ? session.visibleResults.count : session.results.count,
                                expanded: session.resultsExpanded || listingQuery,
                                identifier: "results-toggle"
                            ) { session.resultsExpanded.toggle() }
                            .padding(.top, 16)
                            if session.resultsExpanded || listingQuery {
                                if session.visibleResults.isEmpty {
                                    emptyLine(Copy.t("没有叫这个名字的结果", "No results match this search"))
                                }
                                ForEach(session.visibleResults, id: \.id) { record in
                                    let item = record.takeawayItem()
                                    WorkbenchFileRow(
                                        item: item,
                                        selected: session.paneFocus == .result && session.selectedResultID == record.id,
                                        isResult: true,
                                        caption: record.timeLabel,
                                        group: [],
                                        onSelect: { _ in session.selectResult(record.id) },
                                        onOpen: { session.openItem(item) },
                                        onCopy: { session.copyItem(item) },
                                        onHide: { session.hideResult(record.id) },
                                        onDelete: { session.deleteResult(record.id) },
                                        onBeginDrag: { session.beginShelfDrag(ids: [item.id]) }
                                    )
                                    .id("result-" + record.id.rawValue)
                                }
                            }
                        }
                        directoryHeader(
                            Copy.t("剪贴板历史", "Clipboard"),
                            systemImage: "list.clipboard",
                            tone: .ochre,
                            count: listingQuery ? session.visibleClips.count : session.clipRecords.count,
                            expanded: session.clipboardExpanded || listingQuery,
                            identifier: "clipboard-toggle"
                        ) { session.clipboardExpanded.toggle() }
                        .padding(.top, session.results.isEmpty ? 16 : 8)
                        if session.clipboardExpanded || listingQuery {
                            if session.clipRecords.isEmpty {
                                emptyLine(Copy.t("复制的文字、链接与图片会留在这里", "Copied text, links, and images appear here"))
                            } else if session.visibleClips.isEmpty {
                                emptyLine(Copy.t("没有叫这个名字的记录", "No clipboard rows match this search"))
                            }
                            ForEach(Array(session.visibleClips.prefix(listingQuery || allClips ? 10 : 3))) { record in
                                clipRow(record).id("clip-" + record.id.rawValue)
                            }
                            if listingQuery == false, session.clipRecords.count > 3 {
                                Button(allClips ? Copy.t("收起", "Show less") : Copy.t("查看全部 \(session.clipRecords.count) 条", "View all \(session.clipRecords.count) clips")) { allClips.toggle() }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Palette.muted)
                                    .padding(.leading, 9 + WorkbenchSidebarLayout.fileIndent)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 16)
                }
                .onChange(of: scrollTarget) { _, target in
                    expandFocusedDirectory()
                    if let id = session.selectedClipboard?.id,
                       let index = session.clipRecords.firstIndex(where: { $0.id == id }), index >= 3 { allClips = true }
                    if let target { proxy.scrollTo(target) }
                }
                .onChange(of: allClips) { _, _ in if let target = scrollTarget { proxy.scrollTo(target) } }
                .onChange(of: session.items.count) { _, count in if count > 0 { session.materialsExpanded = true } }
                .onChange(of: session.results.count) { _, count in if count > 0 { session.resultsExpanded = true } }
            }
            HStack {
                Text(session.paneFocus == .input && session.selectedItems.count > 1
                    ? Copy.t("已选 \(session.selectedItems.count) 份材料", "\(session.selectedItems.count) files selected")
                    : Copy.t("副本工作区", "Working copies"))
                Spacer()
                Text(Copy.t("⌘V 粘贴当前", "⌘V pastes current"))
            }
            .font(.system(size: 10.5))
            .foregroundStyle(Palette.faint)
            .padding(16)
        }
        .background(Palette.panel2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workbench-sidebar")
        .background(AccessibleID(identifier: "workbench-sidebar").frame(width: 0, height: 0).allowsHitTesting(false))
    }

    private var listingQuery: Bool { session.shelfQuery.isEmpty == false }

    private var searchBar: some View {
        HStack(spacing: 4) {
            HeaderSearchField(session: session)
            Button { session.pickFilesToAdmit() } label: { Image(systemName: "plus") }
                .help(Copy.t("添加材料", "Add files"))
                .accessibilityIdentifier("shelf-add")
                .background(AccessibleID(identifier: "shelf-add").frame(width: 0, height: 0).allowsHitTesting(false))
            Menu {
                Button(Copy.t("粘贴当前剪贴板", "Paste current clipboard")) { session.pasteFromClipboard() }
                    .accessibilityIdentifier("shelf-paste")
                Button(session.multiSelect ? Copy.t("结束多选", "Finish selecting") : Copy.t("多选材料", "Select multiple files")) { session.setMultiSelect(!session.multiSelect) }
                    .accessibilityIdentifier("multi-select")
            } label: { Image(systemName: "ellipsis") }
            .menuIndicator(.hidden)
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .buttonStyle(IconButtonStyle(size: 22))
        .accessibilityIdentifier("sidebar-search-bar")
    }

    private var scrollTarget: String? {
        switch session.paneFocus {
        case .input: session.selectedItems.first.map { "material-" + $0.id.rawValue }
        case .result: session.selectedResultID.map { "result-" + $0.rawValue }
        case .clipboard: session.selectedClipboard.map { "clip-" + $0.id.rawValue }
        }
    }

    private func expandFocusedDirectory() {
        switch session.paneFocus {
        case .input: session.materialsExpanded = true
        case .result: session.resultsExpanded = true
        case .clipboard: session.clipboardExpanded = true
        }
    }

    private func directoryHeader(
        _ title: String,
        systemImage: String,
        tone: Palette.IconTone,
        count: Int,
        expanded: Bool,
        identifier: String,
        toggle: @escaping () -> Void
    ) -> some View {
        Button(action: toggle) {
            HStack(spacing: 6) {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: 10)
                Image(systemName: systemImage)
                    .foregroundStyle(tone.ink)
                    .font(.system(size: 13))
                Text(title)
                Spacer(minLength: 0)
                Text("\(count)").monospacedDigit()
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Palette.muted)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .background(AccessibleID(identifier: identifier).frame(width: 0, height: 0).allowsHitTesting(false))
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(expanded ? Copy.t("已展开", "Expanded") : Copy.t("已折叠", "Collapsed"))
    }

    private func emptyLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundStyle(Palette.faint)
            .padding(.leading, 9 + WorkbenchSidebarLayout.fileIndent)
            .padding(.vertical, 8)
            .padding(.trailing, 9)
    }

    private func fileRow(_ item: Item) -> some View {
        WorkbenchFileRow(
            item: item,
            selected: session.paneFocus == .input && session.shelf.selection.contains(item.id),
            group: session.selectedItems,
            onSelect: { session.selectMaterial(item.id, extending: $0 || session.multiSelect) },
            onOpen: { session.openItem(item) },
            onCopy: { session.copyItem(item) },
            onHide: { session.hideItem(item.id) },
            onDelete: { session.deleteItem(item.id) },
            onBeginDrag: { session.beginShelfDrag(ids: PasteboardService.exportGroup(starting: item, selection: session.selectedItems).map(\.id)) }
        )
    }

    private func clipRow(_ record: ClipRecord) -> some View {
        WorkbenchClipRow(session: session, record: record)
    }
}

struct WorkbenchFileRow: View {
    let item: Item
    let selected: Bool
    var isResult = false
    var caption = ""
    let group: [Item]
    var onSelect: (Bool) -> Void
    var onOpen: () -> Void
    var onCopy: () -> Void
    var onHide: () -> Void
    var onDelete: () -> Void
    var onBeginDrag: () -> Void
    @State private var hovering = false
    @State private var lastClick = Date.distantPast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: FileKindGlyph.symbol(kind: item.kind, tag: item.displayTag))
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(tone.ink)
                .frame(width: 16)
            Text(item.title)
                .font(.system(size: 12))
                .foregroundStyle(selected ? Palette.text : Palette.muted)
                .lineLimit(1)
                .truncationMode(.middle)
            if caption.isEmpty == false && showsActions == false {
                Text(caption)
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.faint)
            }
            Spacer(minLength: 0)
            if !showsActions { statusMark }
        }
        .padding(.trailing, showsActions ? 68 : 0)
        .contentShape(Rectangle())
        .onTapGesture {
            let now = Date()
            onSelect(ClickModifiers.command)
            if !ClickModifiers.command && now.timeIntervalSince(lastClick) < NSEvent.doubleClickInterval {
                onOpen()
                lastClick = .distantPast
            } else {
                lastClick = now
            }
        }
        .padding(.leading, 9 + WorkbenchSidebarLayout.fileIndent)
        .padding(.trailing, 4)
        .frame(height: 31)
        .background(fill)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(alignment: .trailing) {
            if showsActions {
                WorkbenchRowActions(
                    copy: onCopy,
                    hide: onHide,
                    delete: onDelete,
                    enabled: item.status != .running,
                    copyID: isResult ? "result-copy" : "item-copy",
                    hideID: isResult ? "hide-result" : "hide-item",
                    deleteID: isResult ? "delete-result" : "delete-item"
                )
                .padding(.trailing, 2)
                .background(fill)
            }
        }
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : Palette.motion, value: showsActions)
        .modifier(RowDrag(item: item, group: group, onBegin: onBeginDrag))
        .help(item.title)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(isResult ? "result-\(item.id.rawValue)" : "item-\(item.id.rawValue)")
        .accessibilityAction { onSelect(false) }
        .accessibilityAction(named: Copy.t("复制", "Copy"), onCopy)
        .accessibilityAction(named: Copy.t("隐藏", "Hide from list"), onHide)
        .accessibilityAction(named: Copy.t("删除副本", "Delete copy"), onDelete)
    }

    private var showsActions: Bool { hovering || selected }

    private var fill: Color { selected ? Palette.panelPress : hovering ? Palette.panelHover : Color.clear }

    @ViewBuilder private var statusMark: some View {
        if item.status == .running { ProgressView().controlSize(.mini) }
        else if item.status == .confirm { Image(systemName: "circle.dotted").foregroundStyle(Palette.muted) }
        else if item.status == .failed { Image(systemName: "exclamationmark.circle").foregroundStyle(Palette.warning) }
    }

    private var tone: Palette.IconTone {
        switch item.kind {
        case .folder: .ochre
        case .pdf: .clay
        case .image: .plum
        case .url, .web: .blue
        default: .slate
        }
    }
}

private struct WorkbenchClipRow: View {
    @ObservedObject var session: AppSession
    let record: ClipRecord
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selected: Bool { session.paneFocus == .clipboard && session.clipSelection.contains(record.id) }
    private var showsActions: Bool { hovering || selected }
    private var canUse: Bool { session.clipboardPayload(for: record) != nil }
    private var fill: Color { selected ? Palette.panelPress : hovering ? Palette.panelHover : Color.clear }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: record.kind == .image ? "photo" : record.kind == .url ? "link" : record.kind == .files ? "doc.on.doc" : "text.alignleft")
                    .foregroundStyle(record.kind == .image ? Palette.IconTone.plum.ink : Palette.IconTone.blue.ink)
                    .frame(width: 16)
                Text(record.title).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 0)
                if record.fingerprint == session.currentClipFingerprint {
                    Text(Copy.t("当前", "Current")).font(.system(size: 9)).foregroundStyle(Palette.muted)
                }
                if record.filesMissing {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(Palette.warning)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { session.selectClipboard(record.id, extending: ClickModifiers.command) }
            if showsActions {
                WorkbenchRowActions(
                    copy: { session.makeClipCurrent(record.id) },
                    admit: admit,
                    delete: { session.deleteClip(record.id) },
                    enabled: true,
                    copyEnabled: canUse,
                    admitEnabled: canUse,
                    copyID: "clip-row-copy",
                    admitID: "clip-row-admit",
                    deleteID: "clip-row-delete"
                )
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(Palette.text)
        .padding(.leading, 9 + WorkbenchSidebarLayout.fileIndent)
        .padding(.trailing, 4)
        .frame(height: 31)
        .background(fill)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : Palette.motion, value: showsActions)
        .onDrag { session.beginClipDrag(starting: record.id) }
        .help(record.title)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(record.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("clip-row-\(record.id.rawValue)")
        .accessibilityAction(named: Copy.t("复制", "Copy")) { session.makeClipCurrent(record.id) }
        .accessibilityAction(named: Copy.t("加入材料", "Add to materials"), admit)
        .accessibilityAction(named: Copy.t("删除记录", "Delete clip")) { session.deleteClip(record.id) }
    }

    private func admit() {
        if session.clipSelection.contains(record.id) == false {
            session.selectClipboard(record.id)
        }
        session.admitSelectedClips()
    }
}

private struct WorkbenchRowActions: View {
    var copy: (() -> Void)?
    var admit: (() -> Void)?
    var hide: (() -> Void)?
    var delete: (() -> Void)?
    var enabled = true
    var copyEnabled = true
    var admitEnabled = true
    var copyID = ""
    var admitID = ""
    var hideID = ""
    var deleteID = ""

    var body: some View {
        HStack(spacing: 0) {
            if let copy {
                action("doc.on.doc", Copy.t("复制", "Copy"), copyID, enabled && copyEnabled, copy)
            }
            if let admit {
                action("tray.and.arrow.down", Copy.t("加入材料", "Add to materials"), admitID, enabled && admitEnabled, admit)
            }
            if let hide {
                action("xmark", Copy.t("隐藏（列表拿掉，副本还在）", "Hide from list, keep the copy"), hideID, enabled, hide)
            }
            if let delete {
                Button(action: delete) {
                    Image(systemName: "trash")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Palette.danger)
                }
                .buttonStyle(IconButtonStyle(size: 24))
                .disabled(!enabled)
                .help(Copy.t("删除副本", "Delete copy"))
                .accessibilityLabel(Copy.t("删除副本", "Delete copy"))
                .accessibilityIdentifier(deleteID)
                .background(AccessibleID(identifier: deleteID).frame(width: 0, height: 0).allowsHitTesting(false))
            }
        }
    }

    private func action(_ symbol: String, _ label: String, _ identifier: String, _ on: Bool, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
        }
        .buttonStyle(IconButtonStyle(size: 24))
        .disabled(!on)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
        .background(AccessibleID(identifier: identifier).frame(width: 0, height: 0).allowsHitTesting(false))
    }
}

private enum WorkbenchSidebarLayout {
    static let fileIndent: CGFloat = 12
}
