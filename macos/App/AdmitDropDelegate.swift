import DropAgentIngest
import SwiftUI
import UniformTypeIdentifiers

struct AdmitDropDelegate: DropDelegate {
    @Binding var targeted: Bool
    let admit: ([NSItemProvider]) -> Void

    func validateDrop(info: DropInfo) -> Bool { true }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .copy)
    }

    func dropEntered(info: DropInfo) {
        targeted = true
    }

    func dropExited(info: DropInfo) {
        targeted = false
    }

    func performDrop(info: DropInfo) -> Bool {
        targeted = false
        let providers = info.itemProviders(for: IncomingDrop.contentTypes)
        if providers.isEmpty == false {
            admit(providers)
            return true
        }
        if ClipboardPayload.hasDragCargo(NSPasteboard(name: .drag)) {
            admit([])
            return true
        }
        return false
    }
}
