import AppKit
import DropAgentIngest
import DropAgentShelf
import SwiftUI

struct StageEditor: NSViewRepresentable {
    let itemID: ItemID
    let url: URL
    var inboxRoot: URL
    var jobsRoot: URL
    var usesCodeFont: Bool
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.backgroundColor = .clear
        scroll.focusRingType = .none
        scroll.scrollerStyle = .overlay

        let text = StageTextView(frame: .zero)
        text.isRichText = false
        text.importsGraphics = false
        text.allowsImageEditing = false
        text.isAutomaticQuoteSubstitutionEnabled = false
        text.isAutomaticDashSubstitutionEnabled = false
        text.isAutomaticTextReplacementEnabled = false
        text.isAutomaticSpellingCorrectionEnabled = false
        text.usesAdaptiveColorMappingForDarkAppearance = false
        text.drawsBackground = false
        text.backgroundColor = .clear
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true
        text.textContainer?.containerSize = NSSize(width: 100, height: CGFloat.greatestFiniteMagnitude)
        text.textContainerInset = NSSize(width: 4, height: 6)
        text.allowsUndo = true
        text.delegate = context.coordinator
        text.setAccessibilityIdentifier("content-stage-editor")
        text.setAccessibilityLabel(Copy.t("编辑副本", "Edit copy"))
        text.onCancel = onCancel
        text.focusRequested = true
        scroll.documentView = text
        applyChrome(text, code: usesCodeFont)
        context.coordinator.load(into: text, url: url, itemID: itemID, inboxRoot: inboxRoot, jobsRoot: jobsRoot)
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let text = nsView.documentView as? NSTextView else { return }
        context.coordinator.inboxRoot = inboxRoot
        context.coordinator.jobsRoot = jobsRoot
        (text as? StageTextView)?.onCancel = onCancel
        applyChrome(text, code: usesCodeFont)
        if context.coordinator.itemID != itemID || context.coordinator.url != url {
            context.coordinator.flush()
            context.coordinator.load(into: text, url: url, itemID: itemID, inboxRoot: inboxRoot, jobsRoot: jobsRoot)
        }
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        MainActor.assumeIsolated {
            coordinator.flush()
        }
    }

    private func applyChrome(_ text: NSTextView, code: Bool) {
        let font: NSFont = code
            ? .monospacedSystemFont(ofSize: 12, weight: .regular)
            : .systemFont(ofSize: 12)
        if text.font != font { text.font = font }
        text.textColor = Palette.textNS
        text.insertionPointColor = Palette.textNS
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var itemID: ItemID?
        var url: URL?
        var inboxRoot = URL(fileURLWithPath: "/tmp")
        var jobsRoot = URL(fileURLWithPath: "/tmp")
        private weak var textView: NSTextView?

        func load(into text: NSTextView, url: URL, itemID: ItemID, inboxRoot: URL, jobsRoot: URL) {
            StageEdit.flush()
            self.itemID = itemID
            self.url = url
            self.inboxRoot = inboxRoot
            self.jobsRoot = jobsRoot
            self.textView = text
            let body = StageEdit.read(url)
            if text.string != body {
                text.delegate = nil
                text.string = body
                text.delegate = self
            }
            text.undoManager?.removeAllActions()
        }

        func flush() {
            if let url, let text = textView {
                StageEdit.schedule(text.string, to: url, inboxRoot: inboxRoot, jobsRoot: jobsRoot)
            }
            StageEdit.flush()
        }

        nonisolated func textDidChange(_ notification: Notification) {
            Task { @MainActor in
                self.commitTyping()
            }
        }

        private func commitTyping() {
            guard let text = textView, let url else { return }
            guard text.hasMarkedText() == false else { return }
            StageEdit.schedule(text.string, to: url, inboxRoot: inboxRoot, jobsRoot: jobsRoot)
        }
    }
}

private final class StageTextView: NSTextView {
    var onCancel: (() -> Void)?
    var focusRequested = false {
        didSet { if focusRequested { requestFocus() } }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        requestFocus()
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }
        super.keyDown(with: event)
    }

    private func requestFocus() {
        guard focusRequested, window != nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.focusRequested, self.window?.firstResponder !== self else { return }
            self.window?.makeFirstResponder(self)
        }
    }
}
