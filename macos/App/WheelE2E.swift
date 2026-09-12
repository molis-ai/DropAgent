import AppKit
import DropAgentShelf
import SwiftUI

/// Drives the production drag controller and AppKit destination with explicit event coordinates.
/// It does not synthesize OS mouse input or stand in for a Finder gesture test.
@MainActor
enum WheelE2E {
    static func run() {
        var failures: [String] = []
        func check(_ condition: Bool, _ message: String) {
            if !condition { failures.append(message) }
        }
        let session = AppSession()
        session.prefs.showDropWheel = true
        var panelVisible = false
        guard let screen = NSScreen.main else { fail(["no screen"]) }
        let center = NSPoint(x: screen.visibleFrame.midX, y: screen.visibleFrame.midY)
        // The shelf petal is 96pt above the center; the panel starts 40pt beyond it.
        var panelFrame = NSRect(x: center.x - 100, y: center.y + 136, width: 200, height: 180)
        var panelWakeCount = 0
        let edge = EdgeDropController(
            session: session,
            panelVisible: { panelVisible },
            panelFrame: { panelFrame },
            onDragOverPanel: { panelWakeCount += 1 },
            onDragAwayFromPanel: {}
        )
        edge.setup()
        session.onFinishExternalDrag = { edge.hide() }
        defer { session.finishExternalDrag() }
        guard let view = NSApp.windows.compactMap({ $0.contentView as? EdgeDropView }).last,
              let window = view.window else { fail(["no production wheel view"]) }

        let board = NSPasteboard(name: .drag)
        let top = NSPoint(x: center.x, y: center.y + 96)
        let startTime = Date()
        let files = ["wheel-first.txt", "wheel-second.txt"]
        let bodies = ["first file, independent contents\n", "second file, different contents\n"]
        defer {
            for item in session.items where files.contains(item.title) { session.remove(id: item.id) }
        }
        var sources: [URL] = []
        for (index, name) in files.enumerated() {
            let source = DropAgentPaths.root.appendingPathComponent(name)
            do { try Data(bodies[index].utf8).write(to: source) }
            catch { fail(["write source: \(error)"]) }
            sources.append(source)
            board.clearContents()
            board.writeObjects([source as NSURL])
            let time = startTime.addingTimeInterval(Double(index))
            edge.handleDrag(type: .leftMouseDragged, at: center, now: time)
            edge.handleDrag(type: .leftMouseDragged, at: center, now: time.addingTimeInterval(0.3))
            check(window.isVisible, "drag \(index + 1) did not reveal")
            if index == 1 {
                // Finder payload may disappear while the already recognized drag continues.
                board.clearContents()
            }
            edge.handleDrag(type: .leftMouseDragged, at: top, now: time.addingTimeInterval(0.4))
            check(window.isVisible, "drag \(index + 1) vanished before release")
            check(session.systemDragActive, "drag \(index + 1) ended while still moving")
            let info = WheelDragInfo(window: window, pasteboard: board, screenPoint: top, sequence: index + 1)
            check(view.draggingEntered(info) == .copy, "shelf petal did not accept drag")
            check(view.prepareForDragOperation(info), "shelf petal not ready for drop")
            check(view.performDragOperation(info), "drag \(index + 1) reported failure after admission")
            edge.handleDrag(type: .leftMouseUp, at: top)
            view.draggingEnded(info)
            check(!window.isVisible && !session.systemDragActive, "drag \(index + 1) did not clean up")
            check(session.items.filter { $0.title == name }.count == 1, "\(name) missing or admitted more than once")
            check(session.selectedItems.first?.title == name, "newly dropped file not selected")
        }

        let reloaded = ShelfStore(fileURL: DropAgentPaths.shelfFile)
        reloaded.load()
        for (index, name) in files.enumerated() {
            let matches = reloaded.items().filter { $0.title == name }
            check(matches.count == 1, "\(name) not persisted exactly once")
            let copy = matches.first?.parts.first?.url
            check(copy != sources[index], "\(name) did not use a copy")
            check(copy.flatMap { try? String(contentsOf: $0, encoding: .utf8) } == bodies[index], "\(name) staged content differs")
            check((try? String(contentsOf: sources[index], encoding: .utf8)) == bodies[index], "\(name) original changed")
        }

        // Yield to a panel only after the pointer leaves the visible wheel's range.
        panelVisible = true
        board.clearContents()
        board.writeObjects([sources[0] as NSURL])
        edge.handleDrag(type: .leftMouseDragged, at: center, now: startTime.addingTimeInterval(3))
        edge.handleDrag(type: .leftMouseDragged, at: center, now: startTime.addingTimeInterval(3.3))
        edge.handleDrag(type: .leftMouseDragged, at: top, now: startTime.addingTimeInterval(3.4))
        check(window.isVisible, "shelf petal vanished 40pt outside the panel")
        // Just outside the window also remains wheel-owned, even inside the old 12pt idle halo.
        let justOutside = NSPoint(x: center.x, y: panelFrame.minY - 10)
        edge.handleDrag(type: .leftMouseDragged, at: justOutside, now: startTime.addingTimeInterval(3.5))
        check(window.isVisible, "wheel yielded before entering the actual panel")
        let inside = NSPoint(x: center.x, y: panelFrame.minY + 20)
        edge.handleDrag(type: .leftMouseDragged, at: inside, now: startTime.addingTimeInterval(3.6))
        check(!window.isVisible, "wheel did not yield inside the panel")
        check(session.panelDropOffered, "panel drop offer missing over the panel")
        let count = session.items.count
        edge.handleDrag(type: .leftMouseUp, at: inside)
        check(session.items.count == count + 1, "panel release did not admit")
        check(session.panelDropOffered == false, "panel drop offer stayed after release")

        // Finder trace: the panel starts 49pt above the wheel center, before the
        // shelf petal. The visible wheel must own that route and the release.
        panelFrame = NSRect(x: center.x - 100, y: center.y + 49, width: 200, height: 180)
        let overlapSource = DropAgentPaths.root.appendingPathComponent("wheel-panel-overlap.txt")
        let overlapBody = "Finder drag across an overlapping panel\n"
        try? Data(overlapBody.utf8).write(to: overlapSource)
        defer {
            for item in session.items where item.title == overlapSource.lastPathComponent { session.remove(id: item.id) }
        }
        board.clearContents()
        board.writeObjects([overlapSource as NSURL])
        edge.handleDrag(type: .leftMouseDragged, at: center, now: startTime.addingTimeInterval(4))
        edge.handleDrag(type: .leftMouseDragged, at: center, now: startTime.addingTimeInterval(4.3))
        let wakesBeforeRoute = panelWakeCount
        edge.handleDrag(type: .leftMouseDragged, at: NSPoint(x: center.x - 1, y: center.y + 52), now: startTime.addingTimeInterval(4.4))
        check(window.isVisible, "overlapping panel hid the wheel on the route to its shelf petal")
        edge.handleDrag(type: .leftMouseDragged, at: top, now: startTime.addingTimeInterval(4.5))
        check(window.isVisible, "overlapping panel hid the shelf petal")
        check(panelWakeCount == wakesBeforeRoute, "panel woke over the active wheel route")
        let overlapInfo = WheelDragInfo(window: window, pasteboard: board, screenPoint: top, sequence: 3)
        check(view.draggingEntered(overlapInfo) == .copy, "overlapping shelf petal refused Finder drag")
        // The live Finder trace delivered mouse-up before draggingEnded.
        edge.handleDrag(type: .leftMouseUp, at: top)
        view.draggingEnded(overlapInfo)
        let overlappingItems = session.items.filter { $0.title == overlapSource.lastPathComponent }
        check(overlappingItems.count == 1, "overlapping shelf release did not admit exactly once")
        let overlapCopy = overlappingItems.first?.parts.first?.url
        check(overlapCopy.flatMap { try? String(contentsOf: $0, encoding: .utf8) } == overlapBody,
              "overlapping shelf release did not copy the actual file")
        check((try? String(contentsOf: overlapSource, encoding: .utf8)) == overlapBody, "overlapping drop changed original")

        // A drag already over the panel must still go directly to the panel.
        board.clearContents()
        board.writeObjects([sources[0] as NSURL])
        edge.handleDrag(type: .leftMouseDragged, at: top, now: startTime.addingTimeInterval(4.7))
        edge.handleDrag(type: .leftMouseDragged, at: top, now: startTime.addingTimeInterval(5))
        check(!window.isVisible, "wheel appeared over a drag that started in the panel")
        let beforeDirectPanel = session.items.count
        edge.handleDrag(type: .leftMouseUp, at: top)
        check(session.items.count == beforeDirectPanel + 1, "direct panel drop did not admit")

        let left = NSPoint(x: panelFrame.minX + 12, y: panelFrame.minY + 24)
        let leftSource = DropAgentPaths.root.appendingPathComponent("panel-left-drop.txt")
        let leftBody = "Finder drop on the left of the panel\n"
        try? Data(leftBody.utf8).write(to: leftSource)
        defer {
            for item in session.items where item.title == leftSource.lastPathComponent { session.remove(id: item.id) }
        }
        board.clearContents()
        board.writeObjects([leftSource as NSURL])
        edge.handleDrag(type: .leftMouseDragged, at: left, now: startTime.addingTimeInterval(5.1))
        edge.handleDrag(type: .leftMouseDragged, at: left, now: startTime.addingTimeInterval(5.4))
        check(session.panelDropOffered, "left panel drop offer missing")
        let beforeLeft = session.items.count
        edge.handleDrag(type: .leftMouseUp, at: left)
        check(session.items.count == beforeLeft + 1, "left panel release did not admit")
        check(session.items.filter { $0.title == leftSource.lastPathComponent }.count == 1, "left panel drop admitted more than once")

        let bounceSource = DropAgentPaths.root.appendingPathComponent("panel-bounce-drop.txt")
        let bounceBody = "mouse-up before destination callback\n"
        try? Data(bounceBody.utf8).write(to: bounceSource)
        defer {
            for item in session.items where item.title == bounceSource.lastPathComponent { session.remove(id: item.id) }
        }
        board.clearContents()
        board.writeObjects([bounceSource as NSURL])
        edge.handleDrag(type: .leftMouseDragged, at: left, now: startTime.addingTimeInterval(5.42))
        edge.handleDrag(type: .leftMouseDragged, at: left, now: startTime.addingTimeInterval(5.45))
        let bounceHost = PaperHostView(rootView: Color.clear.frame(width: 40, height: 40))
        bounceHost.dropSession = session
        let bounceInfo = WheelDragInfo(window: window, pasteboard: board, screenPoint: left, sequence: 5)
        check(bounceHost.draggingEntered(bounceInfo) == .copy, "bounce host refused Finder drag")
        let beforeBounce = session.items.count
        edge.handleDrag(type: .leftMouseUp, at: left)
        check(session.items.count == beforeBounce + 1, "mouse-up before destination did not admit")
        check(bounceHost.performDragOperation(bounceInfo), "already-admitted drop reported failure")
        check(session.items.count == beforeBounce + 1, "already-admitted drop duplicated")
        bounceHost.draggingEnded(bounceInfo)

        let hostSource = DropAgentPaths.root.appendingPathComponent("panel-host-drop.txt")
        let hostBody = "AppKit destination then mouse-up\n"
        try? Data(hostBody.utf8).write(to: hostSource)
        defer {
            for item in session.items where item.title == hostSource.lastPathComponent { session.remove(id: item.id) }
        }
        board.clearContents()
        board.writeObjects([hostSource as NSURL])
        edge.handleDrag(type: .leftMouseDragged, at: left, now: startTime.addingTimeInterval(5.5))
        edge.handleDrag(type: .leftMouseDragged, at: left, now: startTime.addingTimeInterval(5.8))
        let host = PaperHostView(rootView: Color.clear.frame(width: 40, height: 40))
        host.dropSession = session
        let hostInfo = WheelDragInfo(window: window, pasteboard: board, screenPoint: left, sequence: 4)
        check(host.draggingEntered(hostInfo) == .copy, "panel host refused Finder drag")
        check(host.performDragOperation(hostInfo), "panel host did not admit")
        let afterHost = session.items.count
        edge.handleDrag(type: .leftMouseUp, at: left)
        host.draggingEnded(hostInfo)
        check(session.items.count == afterHost, "panel host plus mouse-up admitted twice")
        check(session.items.filter { $0.title == hostSource.lastPathComponent }.count == 1, "panel host drop duplicated")

        if let first = session.items.first {
            session.beginShelfDrag(ids: [first.id])
            edge.handleDrag(type: .leftMouseDragged, at: inside, now: startTime.addingTimeInterval(6.1))
            check(session.panelDropOffered == false, "shelf drag offered panel drop")
            edge.handleDrag(type: .leftMouseUp, at: inside)
            session.endShelfDrag()
        }

        panelVisible = false
        let countAfterOverlap = session.items.count
        for (index, releaseInCenter) in [false, true].enumerated() {
            board.clearContents()
            board.writeObjects([sources[0] as NSURL])
            let time = startTime.addingTimeInterval(Double(5 + index))
            edge.handleDrag(type: .leftMouseDragged, at: center, now: time)
            edge.handleDrag(type: .leftMouseDragged, at: center, now: time.addingTimeInterval(0.3))
            if !releaseInCenter {
                let outside = NSPoint(x: center.x + 160, y: center.y)
                edge.handleDrag(type: .leftMouseDragged, at: outside, now: time.addingTimeInterval(0.4))
                edge.handleDrag(type: .leftMouseDragged, at: top, now: time.addingTimeInterval(0.5))
                check(!window.isVisible, "dismissed wheel reappeared in the same drag")
            }
            edge.handleDrag(type: .leftMouseUp, at: releaseInCenter ? center : top)
            check(session.items.count == countAfterOverlap, "cancelled or center release admitted a file")
        }
        board.clearContents()
        edge.handleDrag(type: .leftMouseDragged, at: center, now: startTime.addingTimeInterval(8))
        edge.handleDrag(type: .leftMouseDragged, at: center, now: startTime.addingTimeInterval(8.3))
        check(!window.isVisible && !session.systemDragActive, "empty drag reused old cargo")
        if !failures.isEmpty { fail(failures) }
        fputs("e2e: wheel ok — consecutive drops, temporary empty board, AppKit acceptance, persisted copies, overlapping panel route/release, direct panel drop, left panel drop, cancellation\n", stdout)
    }

    private static func fail(_ failures: [String]) -> Never {
        for message in failures { fputs("e2e: wheel FAIL — \(message)\n", stderr) }
        exit(1)
    }
}

@MainActor
private final class WheelDragInfo: NSObject, NSDraggingInfo {
    let draggingDestinationWindow: NSWindow?
    let draggingPasteboard: NSPasteboard
    let draggingLocation: NSPoint
    let draggingSequenceNumber: Int
    let draggingSourceOperationMask: NSDragOperation = .copy
    var draggingSource: Any? { nil }
    var draggedImageLocation: NSPoint { draggingLocation }
    nonisolated var draggedImage: NSImage? { nil }
    var draggingFormation: NSDraggingFormation = .none
    var animatesToDestination = false
    var numberOfValidItemsForDrop = 1
    var springLoadingHighlight: NSSpringLoadingHighlight { .none }

    init(window: NSWindow, pasteboard: NSPasteboard, screenPoint: NSPoint, sequence: Int) {
        draggingDestinationWindow = window
        draggingPasteboard = pasteboard
        draggingLocation = window.convertPoint(fromScreen: screenPoint)
        draggingSequenceNumber = sequence
    }

    func slideDraggedImage(to screenPoint: NSPoint) {}
    nonisolated override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? { nil }
    func resetSpringLoading() {}
    func enumerateDraggingItems(
        options: NSDraggingItemEnumerationOptions,
        for view: NSView?,
        classes classArray: [AnyClass],
        searchOptions: [NSPasteboard.ReadingOptionKey: Any],
        using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void
    ) {}
}
