import AppKit
import DropAgentShelf
import SwiftUI

enum Palette {
    @MainActor static var isDark = false

    static var desk: Color { Color(red: 5 / 255, green: 6 / 255, blue: 7 / 255) }
    static var panel: Color { shade(light: (252, 252, 253), dark: (26, 28, 33)) }
    static var panel2: Color { shade(light: (242, 243, 246), dark: (32, 35, 42)) }
    static var panelHover: Color { shade(light: (233, 237, 246), dark: (41, 46, 58)) }
    static var panelPress: Color { shade(light: (223, 231, 251), dark: (48, 60, 88)) }
    static var ai: Color { panel }
    static var text: Color { shade(light: (31, 39, 43), dark: (243, 243, 240)) }
    static var muted: Color { shade(light: (92, 98, 112), dark: (174, 181, 195)) }
    static var faint: Color { shade(light: (105, 112, 127), dark: (151, 160, 178)) }
    static var line: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor.white.withAlphaComponent(0.12) : NSColor.black.withAlphaComponent(0.1)
        })
    }
    static var blue: Color { shade(light: (54, 92, 218), dark: (166, 187, 255)) }
    static var bluePress: Color { shade(light: (39, 72, 183), dark: (191, 205, 255)) }
    static var onAccent: Color { shade(light: (255, 255, 255), dark: (21, 32, 64)) }
    static var success: Color { accent }
    static var danger: Color { shade(light: (140, 62, 67), dark: (224, 138, 131)) }
    static var warning: Color { shade(light: (138, 106, 50), dark: (210, 176, 110)) }
    static var accent: Color { shade(light: (54, 92, 218), dark: (166, 187, 255)) }
    static var ice: Color { shade(light: (61, 74, 92), dark: (154, 173, 200)) }
    static var run: Color { shade(light: (54, 92, 218), dark: (166, 187, 255)) }
    static var tty: Color { text }
    static var ttyWell: Color { Color(white: 23 / 255) }
    static var ttyMuted: Color { Color(white: 168 / 255) }
    static var field: Color { shade(light: (239, 241, 245), dark: (21, 23, 29)) }

    static func tagFill(kind: ItemKind, tag: String) -> Color {
        switch kindTint(kind: kind, tag: tag) {
        case .pdf: return shade(light: (234, 214, 194), dark: (72, 52, 38))
        case .image: return shade(light: (223, 232, 249), dark: (42, 51, 73))
        case .url: return shade(light: (217, 224, 236), dark: (42, 50, 64))
        case .web: return shade(light: (223, 232, 244), dark: (41, 51, 67))
        case .md: return shade(light: (226, 229, 237), dark: (46, 51, 65))
        case .clip: return shade(light: (236, 224, 200), dark: (72, 56, 32))
        case .dir: return shade(light: (227, 230, 237), dark: (48, 53, 63))
        case .file: return shade(light: (228, 228, 224), dark: (52, 52, 48))
        }
    }

    static func tagInk(kind: ItemKind, tag: String) -> Color {
        switch kindTint(kind: kind, tag: tag) {
        case .pdf: return shade(light: (90, 56, 36), dark: (232, 196, 164))
        case .image: return shade(light: (51, 74, 121), dark: (181, 199, 237))
        case .url: return shade(light: (51, 68, 92), dark: (176, 192, 220))
        case .web: return shade(light: (54, 77, 111), dark: (171, 193, 226))
        case .md: return shade(light: (66, 76, 99), dark: (185, 196, 219))
        case .clip: return shade(light: (90, 67, 32), dark: (232, 204, 150))
        case .dir: return shade(light: (65, 74, 93), dark: (188, 199, 218))
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
        Color(nsColor: NSColor(name: nil) { appearance in
            let pair = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(calibratedRed: pair.0 / 255, green: pair.1 / 255, blue: pair.2 / 255, alpha: 1)
        })
    }

    static var motion: Animation { .easeOut(duration: 0.18) }
    static var selectionMotion: Animation { .spring(response: 0.28, dampingFraction: 0.88) }
    static var overlay: Animation { .easeOut(duration: 0.22) }

    static var paperNS: NSColor {
        MainActor.assumeIsolated {
            isDark
                ? NSColor(calibratedRed: 26 / 255, green: 28 / 255, blue: 33 / 255, alpha: 1)
                : NSColor(calibratedRed: 252 / 255, green: 252 / 255, blue: 253 / 255, alpha: 1)
        }
    }
    static var paper2NS: NSColor {
        MainActor.assumeIsolated {
            isDark
                ? NSColor(calibratedRed: 32 / 255, green: 35 / 255, blue: 42 / 255, alpha: 1)
                : NSColor(calibratedRed: 242 / 255, green: 243 / 255, blue: 246 / 255, alpha: 1)
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
