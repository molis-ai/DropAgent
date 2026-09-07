import AppKit

@MainActor
enum PanelIdle {
    static let delay: TimeInterval = 0.7
    static let alpha: CGFloat = 0.4
    static let halo: CGFloat = 12
    static let approachHalo: CGFloat = 64
    static let fadeDuration: TimeInterval = 0.2
    static let activeLevel = NSWindow.Level.statusBar
    static let recessedLevel = NSWindow.Level.normal

    enum Toggle: Equatable {
        case show
        case wake
        case hide
    }

    static func toggle(visible: Bool, recessed: Bool) -> Toggle {
        if visible == false { return .show }
        if recessed { return .wake }
        return .hide
    }

    static func shouldRecess(
        visible: Bool,
        isKey: Bool,
        mouseInside: Bool,
        exporting: Bool,
        diagnostic: Bool,
        dragging: Bool = false
    ) -> Bool {
        visible && isKey == false && mouseInside == false && exporting == false && diagnostic == false && dragging == false
    }

    static func dragHitsPanel(mouse: NSPoint, frame: NSRect) -> Bool {
        frame.insetBy(dx: -halo, dy: -halo).contains(mouse)
    }

    static func dragApproachingPanel(mouse: NSPoint, frame: NSRect) -> Bool {
        frame.insetBy(dx: -approachHalo, dy: -approachHalo).contains(mouse)
    }

    static func applyRecess(to panel: NSWindow) {
        panel.alphaValue = alpha
        panel.level = recessedLevel
    }

    static func applyActive(to panel: NSWindow) {
        panel.alphaValue = 1
        panel.level = activeLevel
    }
}
