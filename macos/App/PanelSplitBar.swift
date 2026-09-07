import AppKit
import SwiftUI

enum PanelSplitEdge {
    case shelf
    case result
}

struct PanelSplitBar: View {
    @ObservedObject var session: AppSession
    var edge: PanelSplitEdge = .shelf
    @State private var splitDragStart: CGFloat?
    @State private var splitHover = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            SplitHandleView(
                onDrag: { delta in
                    if splitDragStart == nil {
                        splitDragStart = edge == .shelf ? session.shelfWidth : session.resultWidth
                    }
                    let start = splitDragStart ?? 0
                    if edge == .shelf {
                        session.setShelfWidth(start + delta)
                    } else {
                        session.setResultWidth(start - delta)
                    }
                },
                onEnd: {
                    splitDragStart = nil
                    session.persistChrome()
                },
                onHover: { hovering in
                    splitHover = hovering
                }
            )
            Rectangle()
                .fill(splitHover ? Palette.text.opacity(0.22) : Color.clear)
                .frame(width: 1)
                .padding(.vertical, 40)
                .allowsHitTesting(false)
        }
        .frame(width: LivePanelChrome.splitWidth)
        .frame(maxHeight: .infinity)
        .animation(reduceMotion ? nil : Palette.motion, value: splitHover)
        .accessibilityLabel(edge == .shelf ? "调整输入列宽度" : "调整结果列宽度")
        .accessibilityHint(edge == .shelf ? "向右增大输入列" : "向左增大结果列")
        .accessibilityValue("\(Int((edge == .shelf ? session.shelfWidth : session.resultWidth).rounded())) 点")
        .accessibilityAdjustableAction { direction in
            let delta: CGFloat = direction == .increment ? 16 : -16
            if edge == .shelf {
                session.setShelfWidth(session.shelfWidth + delta)
            } else {
                session.setResultWidth(session.resultWidth + delta)
            }
            session.persistChrome()
        }
    }
}

private struct SplitHandleView: NSViewRepresentable {
    var onDrag: (CGFloat) -> Void
    var onEnd: () -> Void
    var onHover: (Bool) -> Void

    func makeNSView(context: Context) -> SplitHandleNSView {
        let view = SplitHandleNSView()
        view.onDrag = onDrag
        view.onEnd = onEnd
        view.onHover = onHover
        return view
    }

    func updateNSView(_ view: SplitHandleNSView, context: Context) {
        view.onDrag = onDrag
        view.onEnd = onEnd
        view.onHover = onHover
    }
}

final class SplitHandleNSView: NSView {
    var onDrag: ((CGFloat) -> Void)?
    var onEnd: (() -> Void)?
    var onHover: ((Bool) -> Void)?
    private var originX: CGFloat = 0
    private var tracking: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return bounds.contains(local) ? self : nil
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking {
            removeTrackingArea(tracking)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.resizeLeftRight.set()
    }

    override func mouseEntered(with event: NSEvent) {
        onHover?(true)
        NSCursor.resizeLeftRight.set()
    }

    override func mouseExited(with event: NSEvent) {
        onHover?(false)
    }

    override func mouseDown(with event: NSEvent) {
        originX = event.locationInWindow.x
        onHover?(true)
    }

    override func mouseDragged(with event: NSEvent) {
        onDrag?(event.locationInWindow.x - originX)
    }

    override func mouseUp(with event: NSEvent) {
        onEnd?()
    }
}
