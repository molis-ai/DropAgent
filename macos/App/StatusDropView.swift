import AppKit
import DropAgentIngest
import SwiftUI

@MainActor
final class StatusDropView: NSView {
    weak var session: AppSession?
    var panelVisible: () -> Bool = { false }
    var onClick: (() -> Void)?
    var onDropAdmitted: (() -> Void)?
    private var ignoreNextClick = false

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        applyHover(true)
    }

    override func mouseExited(with event: NSEvent) {
        applyHover(false)
    }

    func applyHover(_ hovering: Bool) {
        (superview as? NSButton)?.highlight(hovering || panelVisible())
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        ignoreNextClick = true
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.18).cgColor
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { true }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        ignoreNextClick = false
        layer?.backgroundColor = .clear
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        layer?.backgroundColor = .clear
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        layer?.backgroundColor = .clear
        session?.admitPasteboard(sender.draggingPasteboard)
        onDropAdmitted?()
        return true
    }

    override func mouseUp(with event: NSEvent) {
        if ignoreNextClick {
            ignoreNextClick = false
            return
        }
        onClick?()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes(IncomingDrop.draggedTypes)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes(IncomingDrop.draggedTypes)
    }
}

