import AppKit
import SwiftUI

enum Palette {
    @MainActor static var isDark = false

    static var panel: Color { color(light: 0xFCFCFB, dark: 0x19191B) }
    static var panel2: Color { color(light: 0xF5F5F4, dark: 0x111112) }
    static var panelHover: Color { color(light: 0xEEEEEE, dark: 0x242427) }
    static var panelPress: Color { color(light: 0xE8E9EE, dark: 0x28282F) }
    static var text: Color { color(light: 0x292A2E, dark: 0xE9E9ED) }
    static var muted: Color { color(light: 0x74757D, dark: 0x96969F) }
    static var faint: Color { muted }
    static var line: Color { color(light: 0xE8E8E6, dark: 0x2B2B2F) }
    static var accent: Color { color(light: 0x66709E, dark: 0xA6AFD5) }
    static var accentPressed: Color { color(light: 0x4B5874, dark: 0xC5CDE6) }
    static var onAccent: Color { color(light: 0xFAF9F6, dark: 0x2B3142) }
    static var danger: Color { color(light: 0x8C594B, dark: 0xE0B5A5) }
    static var warning: Color { IconTone.ochre.ink }
    static var ice: Color { IconTone.blue.ink }
    static var run: Color { accent }
    static var tty: Color { IconTone.plum.ink }
    static var ttyWell: Color { color(light: 0xF8F7F4, dark: 0x222329) }
    static var ttyMuted: Color { faint }
    static var field: Color { color(light: 0xEEEEED, dark: 0x202023) }
    static var tagFill: Color { IconTone.slate.fill }
    static var tagInk: Color { IconTone.slate.ink }

    enum IconTone {
        case slate, blue, ochre, plum, clay

        var ink: Color {
            switch self {
            case .slate: return Palette.color(light: 0x647DB5, dark: 0x91A8DC)
            case .blue: return Palette.color(light: 0x5684AA, dark: 0x8AB2D5)
            case .ochre: return Palette.color(light: 0xA7803E, dark: 0xC9A566)
            case .plum: return Palette.color(light: 0x9270B1, dark: 0xBC9ADA)
            case .clay: return Palette.color(light: 0xB27460, dark: 0xD29C87)
            }
        }

        var fill: Color {
            switch self {
            case .slate: return Palette.color(light: 0xE7EAF2, dark: 0x3A4155)
            case .blue: return Palette.color(light: 0xE6ECF3, dark: 0x354454)
            case .ochre: return Palette.color(light: 0xF2EBDF, dark: 0x4B4133)
            case .plum: return Palette.color(light: 0xEFE6EF, dark: 0x4C3C4D)
            case .clay: return Palette.color(light: 0xF2E7E1, dark: 0x4D3D37)
            }
        }
    }

    private static func color(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            rgb(appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light)
        })
    }

    private static func rgb(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255, alpha: 1)
    }

    static func current(light: UInt32, dark: UInt32) -> NSColor {
        MainActor.assumeIsolated { rgb(isDark ? dark : light) }
    }

    static var motion: Animation { .easeOut(duration: 0.18) }
    static var selectionMotion: Animation { .spring(response: 0.28, dampingFraction: 0.88) }
    static var overlay: Animation { .easeOut(duration: 0.22) }
    static var floatExpand: Animation { .timingCurve(0.16, 1, 0.3, 1, duration: LivePanelChrome.floatExpandDuration) }
    static var onboardingStep: Animation { .timingCurve(0.16, 1, 0.3, 1, duration: 0.3) }

    static var paperNS: NSColor { current(light: 0xFCFCFB, dark: 0x19191B) }
    static var paper2NS: NSColor { current(light: 0xF5F5F4, dark: 0x111112) }
    static var ttyWellNS: NSColor { current(light: 0xF8F7F4, dark: 0x222329) }
    static var ttyInkNS: NSColor { current(light: 0x383A43, dark: 0xE2E3E9) }
    static var textNS: NSColor { current(light: 0x292A2E, dark: 0xE9E9ED) }
    static var selectionNS: NSColor { current(light: 0xD6DCEB, dark: 0x4D5874) }
    static var mutedNS: NSColor { current(light: 0x74757D, dark: 0x96969F) }
    static var faintNS: NSColor { mutedNS }

    static var ttyOSCDefaults: String {
        MainActor.assumeIsolated {
            isDark
                ? "\u{1b}]10;#e2e3e9\u{07}\u{1b}]11;#222329\u{07}"
                : "\u{1b}]10;#383a43\u{07}\u{1b}]11;#f8f7f4\u{07}"
        }
    }

    static var ttyIdleFill: String {
        MainActor.assumeIsolated {
            isDark
                ? ttyOSCDefaults + "\u{1b}[48;2;34;35;41m\u{1b}[2J\u{1b}[H"
                : ttyOSCDefaults + "\u{1b}[48;2;248;247;244m\u{1b}[2J\u{1b}[H"
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
