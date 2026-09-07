import AppKit
import DropAgentShelf
import SwiftUI

enum Palette {
    @MainActor static var isDark = false

    static var desk: Color { Color(red: 5 / 255, green: 6 / 255, blue: 7 / 255) }
    static var panel: Color { shade(light: (241, 243, 242), dark: (31, 31, 29)) }
    static var panel2: Color { shade(light: (236, 239, 238), dark: (42, 42, 40)) }
    static var panelHover: Color { shade(light: (233, 236, 235), dark: (52, 52, 50)) }
    static var panelPress: Color { shade(light: (226, 229, 228), dark: (62, 62, 60)) }
    static var ai: Color { panel }
    static var text: Color { shade(light: (31, 39, 43), dark: (243, 243, 240)) }
    static var muted: Color { shade(light: (89, 101, 107), dark: (163, 163, 156)) }
    static var faint: Color { shade(light: (93, 105, 111), dark: (138, 138, 132)) }
    static var line: Color {
        MainActor.assumeIsolated { isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.1) }
    }
    static var blue: Color { text }
    static var bluePress: Color { MainActor.assumeIsolated { isDark ? Color.white : Color.black } }
    static var onAccent: Color { panel }
    static var success: Color { mint }
    static var danger: Color { shade(light: (140, 62, 67), dark: (224, 138, 131)) }
    static var warning: Color { shade(light: (138, 106, 50), dark: (210, 176, 110)) }
    static var mint: Color { shade(light: (61, 92, 78), dark: (143, 191, 160)) }
    static var ice: Color { shade(light: (61, 74, 92), dark: (154, 173, 200)) }
    static var run: Color { shade(light: (47, 92, 98), dark: (143, 184, 188)) }
    static var tty: Color { text }
    static var ttyWell: Color { Color(white: 23 / 255) }
    static var ttyMuted: Color { Color(white: 168 / 255) }
    static var field: Color { shade(light: (230, 234, 233), dark: (22, 22, 20)) }

    static func tagFill(kind: ItemKind, tag: String) -> Color {
        switch kindTint(kind: kind, tag: tag) {
        case .pdf: return shade(light: (234, 214, 194), dark: (72, 52, 38))
        case .image: return shade(light: (213, 230, 219), dark: (40, 62, 50))
        case .url: return shade(light: (217, 224, 236), dark: (42, 50, 64))
        case .web: return shade(light: (212, 228, 230), dark: (40, 58, 62))
        case .md: return shade(light: (221, 227, 220), dark: (44, 54, 46))
        case .clip: return shade(light: (236, 224, 200), dark: (72, 56, 32))
        case .dir: return shade(light: (225, 228, 226), dark: (48, 54, 52))
        case .file: return shade(light: (228, 228, 224), dark: (52, 52, 48))
        }
    }

    static func tagInk(kind: ItemKind, tag: String) -> Color {
        switch kindTint(kind: kind, tag: tag) {
        case .pdf: return shade(light: (90, 56, 36), dark: (232, 196, 164))
        case .image: return shade(light: (47, 83, 64), dark: (168, 210, 184))
        case .url: return shade(light: (51, 68, 92), dark: (176, 192, 220))
        case .web: return shade(light: (47, 77, 82), dark: (160, 204, 208))
        case .md: return shade(light: (51, 64, 56), dark: (176, 196, 180))
        case .clip: return shade(light: (90, 67, 32), dark: (232, 204, 150))
        case .dir: return shade(light: (62, 72, 68), dark: (188, 196, 192))
        case .file: return shade(light: (63, 63, 60), dark: (200, 200, 192))
        }
    }

    private enum KindTint { case pdf, image, url, web, md, clip, dir, file }

    private static func kindTint(kind: ItemKind, tag: String) -> KindTint {
        let upper = tag.uppercased()
        if upper == "JSON" { return .md }
        switch kind {
        case .pdf: return .pdf
        case .image: return .image
        case .url: return .url
        case .web: return .web
        case .markdown: return .md
        case .clip: return .clip
        case .folder: return .dir
        case .file: return .file
        }
    }

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
                : NSColor(calibratedRed: 241 / 255, green: 243 / 255, blue: 242 / 255, alpha: 1)
        }
    }
    static var paper2NS: NSColor {
        MainActor.assumeIsolated {
            isDark
                ? NSColor(calibratedRed: 42 / 255, green: 42 / 255, blue: 40 / 255, alpha: 1)
                : NSColor(calibratedRed: 236 / 255, green: 239 / 255, blue: 238 / 255, alpha: 1)
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
