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
    static let panelWidth: CGFloat = 800
    static let panelHeight: CGFloat = 640
    static let shelfDefault: CGFloat = 196
    static let shelfMin: CGFloat = 176
    static let shelfMax: CGFloat = 240
    static let resultDefault: CGFloat = 196
    static let resultMin: CGFloat = 168
    static let resultMax: CGFloat = 240
    static let splitWidth: CGFloat = 16
    static let scrollGutter: CGFloat = 12
    static let columnHeadHeight: CGFloat = 36
    static let shelfOnlyMin: CGFloat = 260
    static let shelfOnlyMax: CGFloat = 280

    static func fittedWidth(
        showWork: Bool,
        showResult: Bool,
        shelfWidth: CGFloat,
        resultWidth: CGFloat
    ) -> CGFloat {
        let shelf = min(shelfMax, max(shelfMin, shelfWidth))
        let result = min(resultMax, max(resultMin, resultWidth))
        switch (showWork, showResult) {
        case (true, true):
            return panelWidth
        case (true, false):
            return panelWidth - result - splitWidth
        case (false, true):
            return shelf + splitWidth + result
        case (false, false):
            return min(shelfOnlyMax, max(shelfOnlyMin, shelf + 64))
        }
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
        let view = NSView(frame: .zero)
        view.setAccessibilityIdentifier(identifier)
        view.setAccessibilityElement(true)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        view.setAccessibilityIdentifier(identifier)
    }
}

final class PaperHostView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        ClickModifiers.installIfNeeded()
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
        for item in stored {
            item.window.ignoresMouseEvents = true
            item.window.alphaValue = 0
            item.window.level = .normal
            item.window.orderOut(nil)
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

