import AppKit
import SwiftUI

enum PanelResize {
    enum Edge: String {
        case west
        case east
        case south
        case southWest
        case southEast
    }

    static let grip: CGFloat = 8
    static let corner: CGFloat = 16

    static func frame(
        start: NSRect,
        from: NSPoint,
        to: NSPoint,
        edge: Edge,
        visible: NSRect
    ) -> NSRect {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let eastAnchored = edge == .west || edge == .southWest
        let northAnchored = edge == .south || edge == .southWest || edge == .southEast
        var width = start.width
        var height = start.height
        switch edge {
        case .east, .southEast:
            width += dx
        case .west, .southWest:
            width -= dx
        case .south:
            break
        }
        if northAnchored {
            height -= dy
        }
        let pad = PanelPlacement.screenPad
        let maxWidth = max(LivePanelChrome.panelMinWidth, visible.width - pad * 2)
        let maxHeight = max(LivePanelChrome.panelMinHeight, visible.height - pad * 2)
        let minWidth = min(LivePanelChrome.panelMinWidth, maxWidth)
        let minHeight = min(LivePanelChrome.panelMinHeight, maxHeight)
        width = min(max(minWidth, width), maxWidth)
        height = min(max(minHeight, height), maxHeight)
        let x = eastAnchored ? start.maxX - width : start.minX
        let y = northAnchored ? start.maxY - height : start.minY
        return PanelPlacement.clamp(NSRect(x: x, y: y, width: width, height: height), visible: visible)
    }
}

extension View {
    func panelResizeHandles() -> some View {
        let pad = LivePanelChrome.dockShadowPad
        let edge = pad + 4
        let skip = pad + PanelResize.corner
        return overlay(alignment: .leading) {
            WindowResizeHandle(edge: .west)
                .frame(width: edge)
                .padding(.vertical, skip)
        }
        .overlay(alignment: .trailing) {
            WindowResizeHandle(edge: .east)
                .frame(width: edge)
                .padding(.vertical, skip)
        }
        .overlay(alignment: .bottom) {
            WindowResizeHandle(edge: .south)
                .frame(height: edge)
                .padding(.horizontal, skip)
        }
        .overlay(alignment: .bottomLeading) {
            WindowResizeHandle(edge: .southWest)
                .frame(width: edge + 4, height: edge + 4)
        }
        .overlay(alignment: .bottomTrailing) {
            WindowResizeHandle(edge: .southEast)
                .frame(width: edge + 4, height: edge + 4)
        }
    }
}

struct WindowResizeHandle: NSViewRepresentable {
    var edge: PanelResize.Edge

    func makeNSView(context: Context) -> WindowResizeView {
        let view = WindowResizeView()
        view.edge = edge
        view.setAccessibilityIdentifier("panel-resize-\(edge.rawValue)")
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.button)
        view.setAccessibilityLabel(Copy.t("调整窗口大小", "Resize window"))
        return view
    }

    func updateNSView(_ view: WindowResizeView, context: Context) {
        view.edge = edge
    }
}

final class WindowResizeView: NSView {
    var edge: PanelResize.Edge = .southEast {
        didSet {
            if oldValue != edge {
                window?.invalidateCursorRects(for: self)
            }
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let panel = window as? DropAgentPanel, panel.userMoving == false else { return }
        panel.beginUserResize(edge: edge, at: panel.convertPoint(toScreen: event.locationInWindow))
    }

    override func mouseDragged(with event: NSEvent) {
        guard let panel = window as? DropAgentPanel else { return }
        panel.continueUserResize(at: panel.convertPoint(toScreen: event.locationInWindow))
    }

    override func mouseUp(with event: NSEvent) {
        (window as? DropAgentPanel)?.endUserResize()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: cursor(for: edge))
    }

    private func cursor(for edge: PanelResize.Edge) -> NSCursor {
        switch edge {
        case .west, .east:
            return .resizeLeftRight
        case .south:
            return .resizeUpDown
        case .southWest, .southEast:
            if #available(macOS 15.0, *) {
                let position: NSCursor.FrameResizePosition = edge == .southEast ? .bottomRight : .bottomLeft
                return NSCursor.frameResize(position: position, directions: [.inward, .outward])
            }
            return .resizeUpDown
        }
    }
}
