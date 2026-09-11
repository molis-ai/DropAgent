import AppKit
import SwiftUI

enum Palette {
    @MainActor static var isDark = false

    static var panel: Color { gray(light: 252, dark: 25) }
    static var panel2: Color { gray(light: 243, dark: 35) }
    static var panelHover: Color { gray(light: 233, dark: 43) }
    static var panelPress: Color { gray(light: 229, dark: 54) }
    static var text: Color { gray(light: 26, dark: 245) }
    static var muted: Color { gray(light: 91, dark: 189) }
    static var faint: Color { gray(light: 98, dark: 183) }
    static var line: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor.white.withAlphaComponent(0.12) : NSColor.black.withAlphaComponent(0.1)
        })
    }
    static var accent: Color { gray(light: 23, dark: 245) }
    static var accentPressed: Color { gray(light: 48, dark: 222) }
    static var onAccent: Color { gray(light: 255, dark: 23) }
    static var danger: Color { text }
    static var warning: Color { text }
    static var ice: Color { muted }
    static var run: Color { text }
    static var tty: Color { text }
    static var ttyWell: Color { gray(light: 252, dark: 23) }
    static var ttyMuted: Color { gray(light: 98, dark: 183) }
    static var field: Color { gray(light: 241, dark: 21) }
    static var tagFill: Color { gray(light: 235, dark: 48) }
    static var tagInk: Color { gray(light: 80, dark: 212) }

    private static func gray(light: CGFloat, dark: CGFloat) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(calibratedWhite: value / 255, alpha: 1)
        })
    }

    static var motion: Animation { .easeOut(duration: 0.18) }
    static var selectionMotion: Animation { .spring(response: 0.28, dampingFraction: 0.88) }
    static var overlay: Animation { .easeOut(duration: 0.22) }
    static var floatExpand: Animation { .timingCurve(0.16, 1, 0.3, 1, duration: LivePanelChrome.floatExpandDuration) }
    static var onboardingStep: Animation { .timingCurve(0.16, 1, 0.3, 1, duration: 0.3) }

    static var paperNS: NSColor {
        MainActor.assumeIsolated {
            isDark
                ? NSColor(calibratedWhite: 25 / 255, alpha: 1)
                : NSColor(calibratedWhite: 252 / 255, alpha: 1)
        }
    }
    static var paper2NS: NSColor {
        MainActor.assumeIsolated {
            isDark
                ? NSColor(calibratedWhite: 35 / 255, alpha: 1)
                : NSColor(calibratedWhite: 243 / 255, alpha: 1)
        }
    }
    static var ttyWellNS: NSColor {
        MainActor.assumeIsolated {
            isDark
                ? NSColor(calibratedWhite: 23 / 255, alpha: 1)
                : NSColor(calibratedWhite: 252 / 255, alpha: 1)
        }
    }
    static var ttyInkNS: NSColor {
        MainActor.assumeIsolated {
            isDark
                ? NSColor(calibratedWhite: 232 / 255, alpha: 1)
                : NSColor(calibratedWhite: 26 / 255, alpha: 1)
        }
    }

    static var ttyOSCDefaults: String {
        MainActor.assumeIsolated {
            isDark
                ? "\u{1b}]10;#e8e8e8\u{07}\u{1b}]11;#171717\u{07}"
                : "\u{1b}]10;#1a1a1a\u{07}\u{1b}]11;#fcfcfc\u{07}"
        }
    }

    static var ttyIdleFill: String {
        MainActor.assumeIsolated {
            isDark
                ? ttyOSCDefaults + "\u{1b}[48;2;23;23;23m\u{1b}[2J\u{1b}[H"
                : ttyOSCDefaults + "\u{1b}[48;2;252;252;252m\u{1b}[2J\u{1b}[H"
        }
    }
    static var textNS: NSColor {
        MainActor.assumeIsolated {
            isDark ? NSColor(calibratedWhite: 245 / 255, alpha: 1) : NSColor(calibratedWhite: 26 / 255, alpha: 1)
        }
    }
    static var selectionNS: NSColor {
        MainActor.assumeIsolated {
            NSColor(calibratedWhite: (isDark ? 70 : 215) / 255, alpha: 1)
        }
    }
    static var mutedNS: NSColor {
        MainActor.assumeIsolated {
            isDark ? NSColor(calibratedWhite: 189 / 255, alpha: 1) : NSColor(calibratedWhite: 91 / 255, alpha: 1)
        }
    }
    static var faintNS: NSColor {
        MainActor.assumeIsolated {
            isDark ? NSColor(calibratedWhite: 183 / 255, alpha: 1) : NSColor(calibratedWhite: 98 / 255, alpha: 1)
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
