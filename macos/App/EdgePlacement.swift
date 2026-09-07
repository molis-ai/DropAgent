import AppKit
import DropAgentIngest

enum WheelBand: Equatable {
    case hole
    case slice(Int)
    case outside
}

enum EdgePlacement {
    static let innerRadius: CGFloat = 64
    static let outerRadius: CGFloat = 128
    static let leaveSlop: CGFloat = 18
    static let sliceCount = 6
    static let sliceDegrees: CGFloat = 60
    static let petalGap: CGFloat = 8
    static let tabSafe: CGFloat = 80
    static let revealDelay: TimeInterval = 0.18
    static let windowPadding: CGFloat = 44
    static let bounceScale: CGFloat = 1.12

    static var windowSize: CGFloat { outerRadius * 2 + windowPadding * 2 }
    static var midRadius: CGFloat { (innerRadius + outerRadius) / 2 }
    static var tileThickness: CGFloat { outerRadius - innerRadius }

    static func screen(for mouse: NSPoint, screens: [NSScreen]) -> NSScreen? {
        screens.first { screen in
            mouse.x >= screen.frame.minX && mouse.x < screen.frame.maxX
                && mouse.y >= screen.frame.minY && mouse.y <= screen.frame.maxY
        }
    }

    static func inTabSafeZone(mouse: NSPoint, screen: NSScreen) -> Bool {
        mouse.y >= screen.frame.maxY - tabSafe
    }

    static func windowFrame(center: NSPoint) -> NSRect {
        let size = windowSize
        return NSRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
    }

    static func leftRange(mouse: NSPoint, center: NSPoint) -> Bool {
        hypot(mouse.x - center.x, mouse.y - center.y) > outerRadius + leaveSlop
    }

    static func band(mouse: NSPoint, center: NSPoint) -> WheelBand {
        band(dx: mouse.x - center.x, dy: mouse.y - center.y)
    }

    static func band(point: NSPoint, in bounds: NSRect) -> WheelBand {
        band(dx: point.x - bounds.midX, dy: point.y - bounds.midY)
    }

    static func sliceIndex(point: NSPoint, in bounds: NSRect) -> Int? {
        if case .slice(let index) = band(point: point, in: bounds) {
            return index
        }
        return nil
    }

    static func tilePath(index: Int, center: NSPoint) -> NSBezierPath {
        let midR = midRadius
        let thickness = tileThickness
        let cap = atan((thickness / 2) / midR) * 180 / .pi
        let inset = cap + petalGap / 2
        let sectorStart = 120 - CGFloat(index) * sliceDegrees
        let sectorEnd = sectorStart - sliceDegrees
        let arc = NSBezierPath()
        arc.appendArc(
            withCenter: center,
            radius: midR,
            startAngle: sectorStart - inset,
            endAngle: sectorEnd + inset,
            clockwise: true
        )
        let stroked = arc.cgPath.copy(
            strokingWithWidth: thickness,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 0
        )
        return NSBezierPath(cgPath: stroked)
    }

    static func tileCenter(index: Int, center: NSPoint) -> NSPoint {
        point(index: index, center: center, radius: midRadius)
    }

    static func point(index: Int, center: NSPoint, radius: CGFloat) -> NSPoint {
        let mid = 90 - CGFloat(index) * sliceDegrees
        let radians = mid * .pi / 180
        return NSPoint(
            x: center.x + radius * cos(radians),
            y: center.y + radius * sin(radians)
        )
    }

    static func dragPasteboardHasPayload(consumedChangeCount: Int) -> Bool {
        let pasteboard = NSPasteboard(name: .drag)
        if pasteboard.changeCount == consumedChangeCount { return false }
        return ClipboardPayload.hasDragCargo(pasteboard)
    }

    static func consumeDragPasteboard(clearCargo: Bool) -> Int {
        let pasteboard = NSPasteboard(name: .drag)
        if clearCargo, ClipboardPayload.hasDragCargo(pasteboard) {
            pasteboard.clearContents()
        }
        return pasteboard.changeCount
    }

    private static func band(dx: CGFloat, dy: CGFloat) -> WheelBand {
        let point = NSPoint(x: dx, y: dy)
        for index in 0..<sliceCount {
            if tilePath(index: index, center: .zero).contains(point) {
                return .slice(index)
            }
        }
        if hypot(dx, dy) < innerRadius { return .hole }
        return .outside
    }
}
