import AppKit
import Foundation
import SwiftUI

final class DropAgentPanel: NSPanel {
    var onMouseInsideChange: ((Bool) -> Void)?
    private var tracking: NSTrackingArea?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func installMouseTracking() {
        guard let contentView else { return }
        if let tracking {
            contentView.removeTrackingArea(tracking)
        }
        let area = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        contentView.addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseInsideChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onMouseInsideChange?(false)
    }
}

enum LivePanelChrome {
    static var styleMask: NSWindow.StyleMask { .borderless }
    static let panelWidth: CGFloat = 1040
    static let panelHeight: CGFloat = 640
    static let dockMinHeight: CGFloat = 168
    static let dockGap: CGFloat = 10
    static let dockShadowPad: CGFloat = 36
    static let paperShadowRadius: CGFloat = 16
    static let paperShadowY: CGFloat = 8
    static let cardRadius: CGFloat = 12
    static let fileCardWidth: CGFloat = 168
    static let fileCardHeight: CGFloat = 80
    static let floatMaxHeight: CGFloat = 360
    static let floatExpandDuration: TimeInterval = 0.28
    static let scrollGutter: CGFloat = 12
    static let columnHeadHeight: CGFloat = 32
    static let shelfOnlyMin: CGFloat = 260
}

struct DockHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = LivePanelChrome.dockMinHeight
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

enum FirstOpen {
    static func shouldReveal(markerExists: Bool, isDiagnostic: Bool) -> Bool {
        isDiagnostic == false && markerExists == false
    }
}

struct AccessibleID: NSViewRepresentable {
    var identifier: String

    func makeNSView(context: Context) -> NSView {
        let view = HitThroughIDView(frame: .zero)
        view.setAccessibilityIdentifier(identifier)
        view.setAccessibilityElement(true)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        view.setAccessibilityIdentifier(identifier)
    }
}

private final class HitThroughIDView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

final class PaperHostView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        ClickModifiers.installIfNeeded()
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor
    }
}

extension View {
    func dropAgentPaper() -> some View {
        clipShape(RoundedRectangle(cornerRadius: LivePanelChrome.cardRadius, style: .continuous))
            .compositingGroup()
            .shadow(
                color: Color.black.opacity(0.18),
                radius: LivePanelChrome.paperShadowRadius,
                y: LivePanelChrome.paperShadowY
            )
    }
}

enum ClickModifiers {
    @MainActor static var command = false
    @MainActor private static var monitor: Any?

    @MainActor
    static func installIfNeeded() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            let command = event.modifierFlags.contains(.command)
            if Thread.isMainThread {
                MainActor.assumeIsolated { ClickModifiers.command = command }
            } else {
                DispatchQueue.main.sync {
                    MainActor.assumeIsolated { ClickModifiers.command = command }
                }
            }
            return event
        }
    }
}

@MainActor
enum StatusChrome {
    private struct Snapshot {
        var window: NSWindow
        var level: NSWindow.Level
        var alpha: CGFloat
        var ignoresMouseEvents: Bool
        var wasVisible: Bool
    }

    private static var stored: [Snapshot] = []
    private static var blockActivateRestore = false

    static var restoresOnActivate: Bool { blockActivateRestore == false }

    static func hideForPrompt() {
        captureStatusWindows()
        for item in stored {
            item.window.ignoresMouseEvents = true
            item.window.alphaValue = 0
            item.window.level = .normal
            item.window.orderOut(nil)
        }
    }

    static func lowerForPicker() {
        captureStatusWindows()
        for item in stored {
            item.window.level = .floating
        }
    }

    private static func captureStatusWindows() {
        NSApp.activate(ignoringOtherApps: true)
        blockActivateRestore = true
        if stored.isEmpty == false { return }
        stored = NSApp.windows.filter { $0.level >= .statusBar }.map { window in
            Snapshot(
                window: window,
                level: window.level,
                alpha: window.alphaValue,
                ignoresMouseEvents: window.ignoresMouseEvents,
                wasVisible: window.isVisible
            )
        }
    }

    static func restore() {
        blockActivateRestore = false
        for item in stored {
            item.window.level = item.level
            item.window.alphaValue = item.alpha
            item.window.ignoresMouseEvents = item.ignoresMouseEvents
            if item.wasVisible {
                item.window.orderFront(nil)
            }
        }
        stored = []
    }

    static func finishPromptKeepHidden() {
        blockActivateRestore = false
    }
}

