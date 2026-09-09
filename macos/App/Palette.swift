import AppKit
import DropAgentShelf
import SwiftUI

enum Palette {
    @MainActor static var isDark = false

    static var panel: Color { shade(light: (252, 252, 253), dark: (26, 28, 33)) }
    static var panel2: Color { shade(light: (242, 243, 246), dark: (32, 35, 42)) }
    static var panelHover: Color { shade(light: (233, 237, 246), dark: (41, 46, 58)) }
    static var panelPress: Color { shade(light: (223, 231, 251), dark: (48, 60, 88)) }
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
    static var danger: Color { shade(light: (140, 62, 67), dark: (224, 138, 131)) }
    static var warning: Color { shade(light: (138, 106, 50), dark: (210, 176, 110)) }
    static var accent: Color { shade(light: (54, 92, 218), dark: (166, 187, 255)) }
    static var ice: Color { shade(light: (61, 74, 92), dark: (154, 173, 200)) }
    static var run: Color { shade(light: (54, 92, 218), dark: (166, 187, 255)) }
    static var tty: Color { text }
    static var ttyWell: Color { shade(light: (252, 252, 253), dark: (23, 23, 23)) }
    static var ttyMuted: Color { shade(light: (105, 112, 127), dark: (168, 168, 168)) }
    static var field: Color { shade(light: (239, 241, 245), dark: (21, 23, 29)) }

    static func tagFill(kind: ItemKind, tag: String) -> Color {
        switch kindTint(kind: kind, tag: tag) {
        case .pdf: return shade(light: (232, 200, 168), dark: (86, 58, 38))
        case .image: return shade(light: (204, 218, 246), dark: (44, 56, 86))
        case .url: return shade(light: (208, 216, 232), dark: (46, 54, 72))
        case .web: return shade(light: (198, 220, 238), dark: (38, 58, 80))
        case .md: return shade(light: (214, 218, 236), dark: (50, 56, 78))
        case .clip: return shade(light: (236, 210, 164), dark: (84, 62, 30))
        case .dir: return shade(light: (222, 214, 198), dark: (62, 56, 46))
        case .file: return shade(light: (224, 220, 208), dark: (58, 56, 48))
        case .code: return shade(light: (210, 216, 232), dark: (46, 54, 74))
        }
    }

    static func tagInk(kind: ItemKind, tag: String) -> Color {
        switch kindTint(kind: kind, tag: tag) {
        case .pdf: return shade(light: (92, 52, 28), dark: (236, 198, 160))
        case .image: return shade(light: (42, 68, 122), dark: (186, 206, 242))
        case .url: return shade(light: (48, 64, 92), dark: (180, 196, 224))
        case .web: return shade(light: (36, 76, 112), dark: (168, 202, 232))
        case .md: return shade(light: (56, 64, 102), dark: (190, 200, 228))
        case .clip: return shade(light: (92, 62, 24), dark: (236, 206, 148))
        case .dir: return shade(light: (78, 64, 44), dark: (214, 200, 176))
        case .file: return shade(light: (68, 64, 52), dark: (210, 206, 190))
        case .code: return shade(light: (48, 60, 96), dark: (186, 198, 228))
        }
    }

    private enum KindTint { case pdf, image, url, web, md, clip, dir, file, code }

    private static func kindTint(kind: ItemKind, tag: String) -> KindTint {
        let upper = tag.uppercased()
        if upper == "JSON" { return .code }
        if upper == "ZIP" { return .file }
        if ["HTML", "HTM", "SWIFT", "PY", "CSS", "YAML", "YML", "XML"].contains(upper) { return .code }
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
    static var floatExpand: Animation { .timingCurve(0.16, 1, 0.3, 1, duration: LivePanelChrome.floatExpandDuration) }

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
    static var ttyWellNS: NSColor {
        MainActor.assumeIsolated {
            isDark
                ? NSColor(calibratedWhite: 23 / 255, alpha: 1)
                : NSColor(calibratedRed: 252 / 255, green: 252 / 255, blue: 253 / 255, alpha: 1)
        }
    }
    static var ttyInkNS: NSColor {
        MainActor.assumeIsolated {
            isDark
                ? NSColor(calibratedWhite: 232 / 255, alpha: 1)
                : NSColor(calibratedRed: 31 / 255, green: 39 / 255, blue: 43 / 255, alpha: 1)
        }
    }

    static var ttyOSCDefaults: String {
        MainActor.assumeIsolated {
            isDark
                ? "\u{1b}]10;#e8e8e8\u{07}\u{1b}]11;#171717\u{07}"
                : "\u{1b}]10;#1f272b\u{07}\u{1b}]11;#fcfcfd\u{07}"
        }
    }

    static var ttyIdleFill: String {
        MainActor.assumeIsolated {
            isDark
                ? ttyOSCDefaults + "\u{1b}[48;2;23;23;23m\u{1b}[2J\u{1b}[H"
                : ttyOSCDefaults + "\u{1b}[48;2;252;252;253m\u{1b}[2J\u{1b}[H"
        }
    }
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
        window.hasShadow = false
        host.safeAreaRegions = []
        host.wantsLayer = true
        host.layer?.isOpaque = false
        host.layer?.backgroundColor = NSColor.clear.cgColor
        host.layer?.cornerRadius = 0
        host.layer?.masksToBounds = false
    }
}
