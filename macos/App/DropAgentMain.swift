import AppKit
import DropAgentIngest

@main
enum DropAgentMain {
    static func main() {
        if CommandLine.arguments.contains("--preview") {
            MainActor.assumeIsolated {
                PanelPreview.run()
            }
            return
        }
        if CommandLine.arguments.contains("--e2e") {
            MainActor.assumeIsolated {
                AppE2E.run()
            }
            return
        }
        if CommandLine.arguments.contains("--capture") {
            PageAdmit.freezeFrontBrowser()
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
