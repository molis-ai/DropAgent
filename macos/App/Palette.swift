import AppKit
import SwiftUI

enum Palette {
    @MainActor static var isDark = false

    static var desk: Color { Color(red: 18 / 255, green: 18 / 255, blue: 18 / 255) }
    static var panel: Color { shade(light: (247, 247, 245), dark: (31, 31, 29)) }
    static var panel2: Color { shade(light: (236, 236, 234), dark: (42, 42, 40)) }
    static var panelHover: Color { shade(light: (226, 226, 224), dark: (52, 52, 50)) }
    static var panelPress: Color { shade(light: (210, 210, 208), dark: (62, 62, 60)) }
    static var ai: Color { panel }
    static var text: Color { shade(light: (17, 17, 17), dark: (243, 243, 240)) }
    static var muted: Color { shade(light: (90, 90, 90), dark: (163, 163, 156)) }
    static var faint: Color { shade(light: (110, 110, 110), dark: (138, 138, 132)) }
    static var line: Color {
        MainActor.assumeIsolated { isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.1) }
    }
    static var blue: Color { text }
    static var bluePress: Color { MainActor.assumeIsolated { isDark ? Color.white : Color.black } }
    static var onAccent: Color { panel }
    static var success: Color { text }
    static var danger: Color { text }
    static var warning: Color { muted }
    static var mint: Color { text }
    static var ice: Color { text }
    static var tty: Color { text }
    static var ttyWell: Color { Color(white: 23 / 255) }
    static var ttyMuted: Color { Color(white: 168 / 255) }
    static var field: Color { shade(light: (255, 255, 255), dark: (22, 22, 20)) }

    private static func shade(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        let pair = MainActor.assumeIsolated { isDark ? dark : light }
        return Color(red: pair.0 / 255, green: pair.1 / 255, blue: pair.2 / 255)
    }

    static var motion: Animation { .easeOut(duration: 0.2) }
    static var overlay: Animation { .easeOut(duration: 0.22) }

    static var paperNS: NSColor {
        MainActor.assumeIsolated {
            isDark
                ? NSColor(calibratedRed: 31 / 255, green: 31 / 255, blue: 29 / 255, alpha: 1)
                : NSColor(calibratedRed: 247 / 255, green: 247 / 255, blue: 245 / 255, alpha: 1)
        }
    }
    static var ttyWellNS: NSColor { NSColor(calibratedWhite: 23 / 255, alpha: 1) }
    static var ttyInkNS: NSColor { NSColor(calibratedWhite: 232 / 255, alpha: 1) }
    static var textNS: NSColor {
        MainActor.assumeIsolated {
            isDark ? NSColor(calibratedWhite: 243 / 255, alpha: 1) : NSColor(calibratedWhite: 17 / 255, alpha: 1)
        }
    }
    static var mutedNS: NSColor {
        MainActor.assumeIsolated {
            isDark ? NSColor(calibratedWhite: 163 / 255, alpha: 1) : NSColor(calibratedWhite: 90 / 255, alpha: 1)
        }
    }
    static var faintNS: NSColor {
        MainActor.assumeIsolated {
            isDark ? NSColor(calibratedWhite: 138 / 255, alpha: 1) : NSColor(calibratedWhite: 110 / 255, alpha: 1)
        }
    }

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
