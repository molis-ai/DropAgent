import AppKit
import DropAgentPasteboard
import DropAgentShelf
import SwiftUI

struct ClipHistoryMenu: View {
    @ObservedObject var session: AppSession
    var scrolling = false
    var cardHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if session.clipRecords.isEmpty == false {
                toolbar
            }
            if session.clipRecords.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Copy.t("还没有记下的剪贴板", "Nothing saved yet"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.text)
                    Text(Copy.t("复制点东西会出现在这里。⌘V 仍直接贴当前。", "Copied items show up here. ⌘V still pastes the current clip."))
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.faint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
            } else if scrolling {
                ScrollView(.vertical, showsIndicators: true) {
                    rows
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                rows
            }
        }
        .frame(width: ClipHistoryWindow.width, alignment: .topLeading)
        .frame(height: scrolling ? cardHeight : nil, alignment: .top)
        .background(Palette.panel)
        .clipShape(RoundedRectangle(cornerRadius: LivePanelChrome.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LivePanelChrome.cardRadius, style: .continuous)
                .stroke(Palette.line)
        )
        .shadow(color: Color.black.opacity(0.18), radius: LivePanelChrome.paperShadowRadius, y: LivePanelChrome.paperShadowY)
        .preferredColorScheme(session.prefs.appearance.colorScheme)
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Copy.t("剪贴板历史", "Clipboard history"))
        .accessibilityIdentifier("clip-history")
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button {
                session.setClipMultiSelect(!session.clipMultiSelect)
            } label: {
                Label(
                    session.clipMultiSelect ? Copy.t("完成", "Done") : Copy.t("多选", "Select"),
                    systemImage: session.clipMultiSelect ? "checkmark.circle.fill" : "checkmark.circle"
                )
                .font(.system(size: 12, weight: session.clipMultiSelect ? .semibold : .medium))
                .foregroundStyle(Palette.text)
                .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("clip-multi-select")
            Spacer(minLength: 0)
            if session.clipSelection.isEmpty == false {
                Text(Copy.t("已选 \(session.clipSelection.count)", "\(session.clipSelection.count) selected"))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Palette.muted)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: LivePanelChrome.columnHeadHeight)
        .background(Palette.panel2)
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(session.clipRecords) { record in
                ClipHistoryRow(session: session, record: record)
            }
        }
    }
}

private struct ClipHistoryRow: View {
    @ObservedObject var session: AppSession
    let record: ClipRecord
    @State private var hovering = false

    private var isCurrent: Bool { session.currentClipFingerprint == record.fingerprint }
    private var selected: Bool { session.clipSelection.contains(record.id) }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isCurrent ? Palette.text : Color.clear)
                .overlay(Circle().stroke(isCurrent ? Palette.text : Palette.line, lineWidth: 1))
                .frame(width: 7, height: 7)
                .accessibilityLabel(isCurrent ? Copy.t("当前剪贴板", "Current clipboard") : "")
                .accessibilityHidden(isCurrent == false)
            FileKindMark(kind: markKind, tag: markTag, compact: true)
            VStack(alignment: .leading, spacing: 1) {
                Text(record.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.faint)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button {
                session.deleteClip(record.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Palette.faint)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
            .accessibilityLabel(Copy.t("删除", "Delete"))
            .accessibilityIdentifier("clip-delete")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(selected ? Palette.panelHover : hovering ? Palette.panelHover.opacity(0.6) : Color.clear)
        .onHover { hovering = $0 }
        .onTapGesture { session.toggleClipSelect(id: record.id, command: ClickModifiers.command) }
        .modifier(ClipRowDrag(session: session, record: record))
        .accessibilityIdentifier("clip-row")
        .accessibilityLabel(record.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var markKind: ItemKind {
        switch record.kind {
        case .text: return .clip
        case .image: return .image
        case .url: return .url
        case .files: return .file
        }
    }

    private var markTag: String {
        switch record.kind {
        case .text: return "CLIP"
        case .image: return "PNG"
        case .url: return "URL"
        case .files:
            let ext = URL(fileURLWithPath: record.filePaths.first ?? "").pathExtension.uppercased()
            if ext.isEmpty { return "FILE" }
            return String(ext.prefix(4))
        }
    }

    private var subtitle: String {
        if record.filesMissing {
            return Copy.t("已经不在了", "Gone")
        }
        switch record.kind {
        case .text: return Copy.t("文本", "Text")
        case .image: return Copy.t("图片", "Image")
        case .url: return Copy.t("链接", "Link")
        case .files: return Copy.t("文件", "File")
        }
    }
}

private struct ClipRowDrag: ViewModifier {
    var session: AppSession
    let record: ClipRecord

    func body(content: Content) -> some View {
        if record.filesMissing {
            content
        } else {
            content.onDrag {
                session.beginClipDrag(starting: record.id)
            } preview: {
                ClipDragChip(
                    title: record.title,
                    extraCount: max(0, session.clipDragGroup(starting: record.id).count - 1)
                )
            }
        }
    }
}

private struct ClipDragChip: View {
    let title: String
    var extraCount = 0

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.text)
                .lineLimit(1)
            if extraCount > 0 {
                Text(Copy.t("及另外 \(extraCount) 项", "and \(extraCount) more"))
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: 260, alignment: .leading)
        .background(Palette.panel)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.black.opacity(0.16), radius: 12, x: 0, y: 6)
    }
}

struct ClipHistoryButton: NSViewRepresentable {
    var session: AppSession

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = ClipHistoryNSButton()
        button.bezelStyle = .inline
        button.isBordered = false
        button.setButtonType(.momentaryChange)
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)
        image?.isTemplate = true
        button.image = image
        button.contentTintColor = NSColor(Palette.faint)
        button.target = context.coordinator
        button.action = #selector(Coordinator.toggle(_:))
        button.identifier = NSUserInterfaceItemIdentifier("shelf-paste")
        button.setAccessibilityLabel(Copy.t("剪贴板历史", "Clipboard history"))
        button.setAccessibilityHelp(
            Copy.t("打开最近十条。快捷键仍直接把当前贴上架子。", "Opens the last ten clips. The shortcut still pastes the current clip onto the shelf.")
        )
        button.toolTip = Copy.t(
            "剪贴板历史。\(session.prefs.pasteHotKey.label) 仍直接贴当前。",
            "Clipboard history. \(session.prefs.pasteHotKey.label) still pastes the current clip."
        )
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.session = session
        button.contentTintColor = NSColor(session.clipHistoryOpen ? Palette.text : Palette.faint)
        button.toolTip = Copy.t(
            "剪贴板历史。\(session.prefs.pasteHotKey.label) 仍直接贴当前。",
            "Clipboard history. \(session.prefs.pasteHotKey.label) still pastes the current clip."
        )
    }

    @MainActor
    final class Coordinator: NSObject {
        var session: AppSession

        init(session: AppSession) {
            self.session = session
        }

        @objc func toggle(_ sender: NSButton) {
            session.toggleClipHistory(anchor: Self.screenFrame(of: sender))
        }

        static func screenFrame(of view: NSView) -> CGRect {
            guard let window = view.window else {
                let point = NSEvent.mouseLocation
                return CGRect(x: point.x - 11, y: point.y - 11, width: 22, height: 22)
            }
            return window.convertToScreen(view.convert(view.bounds, to: nil))
        }
    }
}

private final class ClipHistoryNSButton: NSButton {
    override var intrinsicContentSize: NSSize { NSSize(width: 22, height: 22) }
}

@MainActor
final class ClipHistoryWindow {
    static let width: CGFloat = 280
    static let maxHeight: CGFloat = 320

    private var panel: NSPanel?
    private var host: NSHostingView<ClipHistoryMenu>?
    private var session: AppSession?
    private var lastAnchor: CGRect = .zero
    private var localMonitor: Any?
    private var globalMonitor: Any?

    func containsPointer(_ point: NSPoint) -> Bool {
        guard let panel, panel.isVisible else { return false }
        return panel.frame.contains(point)
    }

    func show(session: AppSession, anchor: CGRect) {
        self.session = session
        lastAnchor = anchor
        apply(session: session)
        let panel = self.panel ?? makePanel()
        panel.contentView = host
        self.panel = panel
        layout()
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
        panel.orderFrontRegardless()
        installMonitors()
        DispatchQueue.main.async { [weak self] in
            self?.layout()
        }
    }

    private func apply(session: AppSession) {
        let measured = measure(session)
        let scrolling = measured.height > Self.maxHeight + 0.5
        let height = min(max(measured.height, 48), Self.maxHeight)
        let root = ClipHistoryMenu(session: session, scrolling: scrolling, cardHeight: height)
        let host = self.host ?? NSHostingView(rootView: root)
        host.safeAreaRegions = []
        host.rootView = root
        host.sizingOptions = scrolling ? [] : [.intrinsicContentSize]
        host.frame = NSRect(origin: .zero, size: CGSize(width: Self.width, height: height))
        self.host = host
    }

    private func measure(_ session: AppSession) -> CGSize {
        let probe = NSHostingView(rootView: ClipHistoryMenu(session: session))
        probe.safeAreaRegions = []
        probe.sizingOptions = [.intrinsicContentSize]
        var size = probe.fittingSize
        if size.width < 40 || size.height < 40 {
            probe.frame.size = NSSize(width: Self.width, height: Self.maxHeight)
            probe.layoutSubtreeIfNeeded()
            size = probe.fittingSize
        }
        size.width = Self.width
        return size
    }

    func relayout() {
        guard panel?.isVisible == true else { return }
        layout()
    }

    func hide() {
        removeMonitors()
        panel?.orderOut(nil)
    }

    private func layout() {
        guard let session, let host, let panel else { return }
        apply(session: session)
        let size = host.frame.size
        panel.setContentSize(size)
        let screen = NSScreen.screens.first { $0.frame.intersects(lastAnchor) }?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? lastAnchor
        panel.setFrame(Self.frame(anchor: lastAnchor, size: size, screen: screen), display: true)
    }

    static func frame(anchor: CGRect, size: CGSize, screen: CGRect) -> CGRect {
        let gap: CGFloat = 4
        let inset: CGFloat = 8
        var x = anchor.maxX - size.width
        var y = anchor.minY - gap - size.height
        if y < screen.minY + inset {
            y = anchor.maxY + gap
        }
        if x < screen.minX + inset {
            x = screen.minX + inset
        }
        if x + size.width > screen.maxX - inset {
            x = screen.maxX - inset - size.width
        }
        if y + size.height > screen.maxY - inset {
            y = screen.maxY - inset - size.height
        }
        if y < screen.minY + inset {
            y = screen.minY + inset
        }
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    private func makePanel() -> NSPanel {
        let panel = ClipHistoryPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        return panel
    }

    private func installMonitors() {
        removeMonitors()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown, event.keyCode == 53 {
                self.session?.closeClipHistory()
                return nil
            }
            if event.type == .keyDown { return event }
            self.dismissIfOutside()
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismissIfOutside()
        }
    }

    private func dismissIfOutside() {
        if session?.clipDragging == true { return }
        let point = NSEvent.mouseLocation
        if panel?.frame.contains(point) == true { return }
        if lastAnchor.insetBy(dx: -6, dy: -6).contains(point) { return }
        session?.closeClipHistory()
    }

    private func removeMonitors() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }
}

@MainActor
final class ClipHistoryPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
