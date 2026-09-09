import AppKit
import DropAgentShelf
import SwiftUI

enum HoverPlacement {
    static let width: CGFloat = 276
    static let gap: CGFloat = 8
    static let maxHeight: CGFloat = 320
    static let minHeight: CGFloat = 72
    static let minWidth: CGFloat = 168
    static let screenInset: CGFloat = 8
    static let cardPadding: CGFloat = 14
    static var innerWidth: CGFloat { width - cardPadding * 2 }

    static func needsScroll(contentHeight: CGFloat, contentWidth: CGFloat = width) -> Bool {
        contentHeight > maxHeight + 0.5 || contentWidth > width + 0.5
    }

    static func sitsLeft(visual: CGRect, panel: CGRect, paperInset: CGFloat = 0) -> Bool {
        let paper = paperRect(panel: panel, paperInset: paperInset)
        return visual.midX < paper.midX
    }

    static func windowFrame(visual: CGRect, sitsLeft: Bool) -> CGRect {
        if sitsLeft {
            return CGRect(
                x: visual.minX,
                y: visual.minY,
                width: visual.width + gap,
                height: visual.height
            )
        }
        return CGRect(
            x: visual.minX - gap,
            y: visual.minY,
            width: visual.width + gap,
            height: visual.height
        )
    }

    static func frame(
        panel: CGRect,
        size: CGSize,
        screen: CGRect,
        paperInset: CGFloat = 0
    ) -> CGRect {
        let paper = paperRect(panel: panel, paperInset: paperInset)
        var x = paper.minX - gap - size.width
        x = max(screen.minX + screenInset, x)
        if x + size.width > screen.maxX - screenInset {
            x = max(screen.minX + screenInset, screen.maxX - screenInset - size.width)
        }

        var y = paper.maxY - size.height
        if y + size.height > screen.maxY - screenInset {
            y = screen.maxY - screenInset - size.height
        }
        if y < screen.minY + screenInset {
            y = screen.minY + screenInset
        }
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    private static func paperRect(panel: CGRect, paperInset: CGFloat) -> CGRect {
        panel.width > paperInset * 2 && panel.height > paperInset * 2
            ? panel.insetBy(dx: paperInset, dy: paperInset)
            : panel
    }
}

@MainActor
final class HoverPreviewWindow {
    /// Leave a file card: keep the preview this long so the pointer can reach the left-of-panel window.
    static let hideDelayNanos: UInt64 = 2_000_000_000

    var panelFrame: () -> CGRect = { .zero }
    private var panel: NSPanel?
    private var host: NSHostingView<HoverPreview>?
    private var hideTask: Task<Void, Never>?
    private(set) var itemID: ItemID?
    private(set) var pointerInside = false

    var ignoresMouseEvents: Bool { panel?.ignoresMouseEvents ?? true }

    func containsPointer(_ point: NSPoint) -> Bool {
        guard let panel, panel.isVisible else { return false }
        return panel.frame.contains(point)
    }

    func show(item: Item, cardInScreen: CGRect) {
        hideTask?.cancel()
        hideTask = nil
        pointerInside = false
        itemID = item.id

        let measured = measure(item)
        let scrolling = HoverPlacement.needsScroll(
            contentHeight: measured.height,
            contentWidth: measured.width
        )
        let visualSize = CGSize(
            width: HoverPlacement.width,
            height: min(max(measured.height, HoverPlacement.minHeight), HoverPlacement.maxHeight)
        )

        let anchor = panelFrame()
        let usingPanel = anchor.width > 1
        let target = usingPanel ? anchor : cardInScreen
        let screen = NSScreen.screens.first { $0.frame.intersects(target) }?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? target
        let paperInset = usingPanel ? LivePanelChrome.dockShadowPad : 0
        let visual = HoverPlacement.frame(
            panel: target,
            size: visualSize,
            screen: screen,
            paperInset: paperInset
        )
        let onLeft = true
        let windowRect = HoverPlacement.windowFrame(visual: visual, sitsLeft: onLeft)

        let root = HoverPreview(
            item: item,
            scrolling: scrolling,
            cardHeight: visualSize.height,
            bridgeOnTrailing: onLeft,
            lockCardWidth: true
        )
        let host = self.host ?? NSHostingView(rootView: root)
        host.safeAreaRegions = []
        host.rootView = root
        host.sizingOptions = []
        host.frame = NSRect(origin: .zero, size: windowRect.size)

        let panel = self.panel ?? makePanel()
        let hit = (panel.contentView as? HoverHitView) ?? HoverHitView(frame: .zero)
        hit.onPointer = { [weak self] on in self?.setPointerInside(on) }
        hit.frame = NSRect(origin: .zero, size: windowRect.size)
        if host.superview !== hit {
            host.removeFromSuperview()
            hit.addSubview(host)
        }
        host.frame = hit.bounds
        host.autoresizingMask = [.width, .height]
        panel.contentView = hit
        panel.ignoresMouseEvents = false
        panel.setContentSize(windowRect.size)
        panel.setFrame(windowRect, display: true)
        panel.orderFrontRegardless()
        self.host = host
        self.panel = panel
    }

    func hide() {
        hideTask?.cancel()
        hideTask = nil
        itemID = nil
        pointerInside = false
        panel?.orderOut(nil)
    }

    func hide(ifMatching id: ItemID) {
        requestHide(ifMatching: id)
    }

    func requestHide(ifMatching id: ItemID? = nil) {
        guard itemID != nil else { return }
        if let id, itemID != id { return }
        if pointerInside { return }
        hideTask?.cancel()
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.hideDelayNanos)
            guard let self, !Task.isCancelled else { return }
            guard self.pointerInside == false else { return }
            if let id, self.itemID != id { return }
            self.hide()
        }
    }

    func setPointerInside(_ on: Bool) {
        pointerInside = on
        if on {
            hideTask?.cancel()
            hideTask = nil
        } else if itemID != nil {
            requestHide(ifMatching: itemID)
        }
    }

    func isolateFromMouse() {
        panel?.ignoresMouseEvents = true
    }

    private func measure(_ item: Item) -> CGSize {
        let probe = NSHostingView(
            rootView: HoverPreview(item: item, lockCardWidth: true, includeBridge: false, unconstrained: true)
        )
        probe.safeAreaRegions = []
        probe.sizingOptions = [.intrinsicContentSize]
        probe.frame.size = NSSize(width: HoverPlacement.width, height: 10_000)
        probe.layoutSubtreeIfNeeded()
        var size = probe.fittingSize
        if size.width < 40 || size.height < 40 {
            size = CGSize(width: HoverPlacement.width, height: HoverPlacement.minHeight)
        }
        size.width = HoverPlacement.width
        return size
    }

    private func makePanel() -> NSPanel {
        let panel = HoverPanel(
            contentRect: NSRect(x: 0, y: 0, width: 276, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient]
        return panel
    }
}

@MainActor
final class HoverPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class HoverHitView: NSView {
    var onPointer: ((Bool) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
        )
    }

    override func mouseEntered(with event: NSEvent) {
        onPointer?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onPointer?(false)
    }
}

struct ScreenRectProbe: NSViewRepresentable {
    var onFrame: (CGRect) -> Void

    func makeNSView(context: Context) -> ProbeView {
        ProbeView(onFrame: onFrame)
    }

    func updateNSView(_ nsView: ProbeView, context: Context) {
        nsView.onFrame = onFrame
        nsView.report()
    }

    final class ProbeView: NSView {
        var onFrame: (CGRect) -> Void

        init(onFrame: @escaping (CGRect) -> Void) {
            self.onFrame = onFrame
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func layout() {
            super.layout()
            report()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            report()
        }

        func report() {
            guard let window, bounds.width > 1, bounds.height > 1 else { return }
            onFrame(window.convertToScreen(convert(bounds, to: nil)))
        }
    }
}
