import AppKit
import SwiftUI

enum Palette {
    static var desk: Color { Color(red: 18 / 255, green: 18 / 255, blue: 18 / 255) }
    static var panel: Color { Color(red: 247 / 255, green: 247 / 255, blue: 245 / 255) }
    static var panel2: Color { Color(red: 236 / 255, green: 236 / 255, blue: 234 / 255) }
    static var panelHover: Color { Color(red: 226 / 255, green: 226 / 255, blue: 224 / 255) }
    static var panelPress: Color { Color(red: 210 / 255, green: 210 / 255, blue: 208 / 255) }
    static var ai: Color { Color(red: 247 / 255, green: 247 / 255, blue: 245 / 255) }
    static var text: Color { Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255) }
    static var muted: Color { Color(red: 90 / 255, green: 90 / 255, blue: 90 / 255) }
    static var faint: Color { Color(red: 120 / 255, green: 120 / 255, blue: 120 / 255) }
    static var line: Color { Color.black.opacity(0.1) }
    static var blue: Color { text }
    static var bluePress: Color { Color.black }
    static var onAccent: Color { panel }
    static var success: Color { text }
    static var danger: Color { text }
    static var warning: Color { muted }
    static var mint: Color { text }
    static var ice: Color { text }
    static var tty: Color { text }
    static var ttyWell: Color { Color(white: 23 / 255) }
    static var ttyMuted: Color { Color(white: 168 / 255) }
    static var field: Color { Color.white }

    static var motion: Animation { .easeOut(duration: 0.2) }
    static var overlay: Animation { .easeOut(duration: 0.22) }

    static var paperNS: NSColor {
        NSColor(calibratedRed: 247 / 255, green: 247 / 255, blue: 245 / 255, alpha: 1)
    }
    static var ttyWellNS: NSColor { NSColor(calibratedWhite: 23 / 255, alpha: 1) }
    static var ttyInkNS: NSColor { NSColor(calibratedWhite: 232 / 255, alpha: 1) }

    static func controlFill(enabled: Bool, hovering: Bool, pressed: Bool) -> Color {
        guard enabled else { return panel2 }
        if pressed { return panelPress }
        if hovering { return panelHover }
        return panel2
    }

    @MainActor
    static func applyPaperChrome<Content: View>(to window: NSWindow, host: NSHostingView<Content>) {
        window.isOpaque = false
        window.backgroundColor = .clear
        host.safeAreaRegions = []
        host.wantsLayer = true
        host.layer?.cornerRadius = 12
        host.layer?.masksToBounds = true
        host.layer?.cornerCurve = .continuous
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
