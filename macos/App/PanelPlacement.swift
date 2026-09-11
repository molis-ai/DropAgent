import AppKit
import Foundation

enum PanelPlacement {
    static let screenPad: CGFloat = 8

    static func underStatusItem(button: NSRect, visible: NSRect, size: NSSize) -> NSRect {
        let width = min(max(LivePanelChrome.shelfOnlyMin, size.width), max(LivePanelChrome.shelfOnlyMin, visible.width - screenPad * 2))
        let top = button.minY - 6
        let maxHeight = max(LivePanelChrome.dockMinHeight, top - (visible.minY + screenPad))
        let height = min(max(LivePanelChrome.dockMinHeight, size.height), maxHeight)
        var x = button.maxX - width
        x = min(max(visible.minX + screenPad, x), max(visible.minX + screenPad, visible.maxX - width - screenPad))
        return clamp(NSRect(x: x, y: top - height, width: width, height: height), visible: visible)
    }

    static func placed(savedX: CGFloat, savedTop: CGFloat, size: NSSize, visible: NSRect) -> NSRect {
        clamp(
            NSRect(x: savedX, y: savedTop - size.height, width: size.width, height: size.height),
            visible: visible
        )
    }

    static func clamp(_ frame: NSRect, visible: NSRect) -> NSRect {
        let width = min(max(LivePanelChrome.shelfOnlyMin, frame.width), max(LivePanelChrome.shelfOnlyMin, visible.width - screenPad * 2))
        let height = min(max(LivePanelChrome.dockMinHeight, frame.height), max(LivePanelChrome.dockMinHeight, visible.height - screenPad * 2))
        var x = frame.origin.x
        var y = frame.origin.y
        let minX = visible.minX + screenPad
        let maxX = visible.maxX - width - screenPad
        let minY = visible.minY + screenPad
        let maxY = visible.maxY - height - screenPad
        if maxX >= minX {
            x = min(max(minX, x), maxX)
        } else {
            x = minX
        }
        if maxY >= minY {
            y = min(max(minY, y), maxY)
        } else {
            y = minY
        }
        return NSRect(x: x, y: y, width: width, height: height)
    }

    static func screen(forSavedX x: CGFloat, top: CGFloat, fallback: NSScreen?) -> NSScreen? {
        let probe = NSPoint(x: x, y: top - 1)
        return NSScreen.screens.first { $0.visibleFrame.insetBy(dx: -1, dy: -1).contains(probe) }
            ?? fallback
            ?? NSScreen.main
    }
}
