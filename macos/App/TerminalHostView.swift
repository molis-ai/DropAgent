import AppKit
import SwiftTerm
import SwiftUI

struct TerminalHostView: NSViewRepresentable {
    @ObservedObject var session: AppSession

    func makeCoordinator() -> Coordinator { Coordinator(session: session) }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let view = FirstMouseTerminalView(frame: .zero)
        view.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        view.wantsLayer = true
        Self.paintChrome(view)
        view.processDelegate = context.coordinator
        context.coordinator.view = view
        return view
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        context.coordinator.session = session
        context.coordinator.view = nsView
        context.coordinator.paintIdleWell(nsView)
        context.coordinator.consumePending()
    }

    static func paintChrome(_ view: LocalProcessTerminalView) {
        let bg = Palette.ttyWellNS
        view.nativeBackgroundColor = bg
        view.nativeForegroundColor = Palette.ttyInkNS
        view.caretColor = Palette.paperNS
        view.backgroundOpacity = 1
        view.layer?.backgroundColor = bg.cgColor
        view.layer?.isOpaque = true
    }

    @MainActor
    final class Coordinator: NSObject, @MainActor LocalProcessTerminalViewDelegate {
        var session: AppSession
        weak var view: LocalProcessTerminalView?
        private var started = false
        private var epoch = UUID()
        private var lastIdleFill = CGSize.zero
        private var previewFed = false
        private var revealWork: DispatchWorkItem?

        init(session: AppSession) { self.session = session }

        func paintIdleWell(_ view: LocalProcessTerminalView) {
            TerminalHostView.paintChrome(view)
            let size = view.bounds.size
            guard started == false, size.width > 8, size.height > 8 else { return }
            if isPreview, session.ptyLive {
                guard size != lastIdleFill || previewFed == false else { return }
                lastIdleFill = size
                previewFed = true
                feedPreview(view)
                return
            }
            guard size != lastIdleFill else { return }
            lastIdleFill = size
            view.feed(text: "\u{1b}]11;#171717\u{07}\u{1b}[48;2;23;23;23m\u{1b}[2J\u{1b}[H")
        }

        func consumePending() {
            if epoch != session.tuiEpoch {
                epoch = session.tuiEpoch
                if started {
                    view?.terminate()
                }
                started = false
                lastIdleFill = .zero
                previewFed = false
                revealWork?.cancel()
                revealWork = nil
                session.ptyLive = false
            }
            guard let prepared = session.pendingTUI, let view else { return }
            session.pendingTUI = nil
            if !started {
                guard FileManager.default.isExecutableFile(atPath: prepared.session.executable.path) else {
                    session.failTUILaunch(itemIDs: prepared.itemIDs)
                    return
                }
                view.startProcess(
                    executable: prepared.session.executable.path,
                    args: prepared.session.arguments,
                    environment: prepared.session.environment,
                    execName: prepared.session.executable.lastPathComponent,
                    currentDirectory: prepared.cwd.path
                )
                started = true
                lastIdleFill = .zero
                previewFed = false
                session.tuiProcessRunning = true
                session.ptyLive = false
                scheduleReveal()
                view.window?.makeKeyAndOrderFront(nil)
                view.window?.makeFirstResponder(view)
                return
            }
            let injection = prepared.injection.hasSuffix("\r") ? prepared.injection : prepared.injection + "\r"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak view] in
                view?.send(txt: injection)
            }
        }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            guard started, title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
            revealWell()
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            started = false
            lastIdleFill = .zero
            previewFed = false
            revealWork?.cancel()
            revealWork = nil
            session.tuiProcessExited()
        }

        private var isPreview: Bool {
            ProcessInfo.processInfo.arguments.contains("--preview")
        }

        private func scheduleReveal() {
            revealWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.revealWell()
            }
            revealWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
        }

        private func revealWell() {
            revealWork?.cancel()
            revealWork = nil
            guard started else { return }
            session.ptyLive = true
        }

        private func feedPreview(_ view: LocalProcessTerminalView) {
            var text = "\u{1b}]11;#171717\u{07}\u{1b}[48;2;23;23;23m\u{1b}[2J\u{1b}[H"
            if session.ttyLines.isEmpty {
                text += "发送后，\(session.tuiTitle) 会出现在这里\r\n"
            } else {
                for line in session.ttyLines {
                    text += line.text + "\r\n"
                }
            }
            view.feed(text: text)
        }
    }
}

private final class FirstMouseTerminalView: LocalProcessTerminalView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
