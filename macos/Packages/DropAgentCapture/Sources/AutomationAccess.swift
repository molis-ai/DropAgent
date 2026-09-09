import AppKit
import ApplicationServices
import Foundation

public enum AutomationState: Equatable, Sendable {
    case allowed
    case denied
    case notDetermined
    case unavailable
}

/// Probe Automation (Apple Events) without presenting the system prompt.
/// Calling osascript when the user has not allowed control is what previously
/// put DropAgent into an uninterruptible wait on the TCC dialog.
public enum AutomationAccess {
    public static func isAllowed(bundleIdentifier: String) -> Bool {
        probe(bundleIdentifier: bundleIdentifier) == .allowed
    }

    public static func probe(bundleIdentifier: String) -> AutomationState {
        silentState(determine(bundleIdentifier: bundleIdentifier, ask: false))
    }

    /// Preserve OS results. A denial is not proof the user explicitly refused.
    public static func silentState(_ state: AutomationState) -> AutomationState { state }

    /// Keep the request in this process so consent belongs to DropAgent.
    public static func requestIfNeededOffMain(bundleIdentifier: String) async -> AutomationState {
        await PermissionWork.run {
            let live = resolvedBundleIdentifier(bundleIdentifier)
            guard runningRegularApp(live) != nil else { return .unavailable }
            if probe(bundleIdentifier: live) == .allowed { return .allowed }
            return determine(bundleIdentifier: live, ask: true)
        }
    }

    public static func resolvedBundleIdentifier(_ bundleIdentifier: String) -> String {
        runningRegularApp(bundleIdentifier)?.bundleIdentifier ?? bundleIdentifier
    }

    private static func determine(bundleIdentifier: String, ask: Bool) -> AutomationState {
        let live = resolvedBundleIdentifier(bundleIdentifier)
        let target = targetDescriptor(bundleIdentifier: live)
        let status = AEDeterminePermissionToAutomateTarget(
            target.aeDesc,
            typeWildCard,
            typeWildCard,
            ask
        )
        return state(from: status)
    }

    private static func targetDescriptor(bundleIdentifier: String) -> NSAppleEventDescriptor {
        if let app = runningRegularApp(bundleIdentifier) {
            var pid = app.processIdentifier
            if let desc = NSAppleEventDescriptor(
                descriptorType: typeKernelProcessID,
                bytes: &pid,
                length: MemoryLayout<pid_t>.size
            ) {
                return desc
            }
        }
        return NSAppleEventDescriptor(bundleIdentifier: bundleIdentifier)
    }

    private static func runningRegularApp(_ bundleIdentifier: String) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { app in
            app.activationPolicy == .regular
                && app.bundleIdentifier?.caseInsensitiveCompare(bundleIdentifier) == .orderedSame
        }
    }

    public static func state(from status: OSStatus) -> AutomationState {
        switch status {
        case noErr:
            return .allowed
        case OSStatus(errAEEventNotPermitted):
            return .denied
        case OSStatus(errAEEventWouldRequireUserConsent):
            return .notDetermined
        default:
            return .unavailable
        }
    }
}
