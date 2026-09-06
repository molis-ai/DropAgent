import ApplicationServices
import Foundation

/// Probe Automation (Apple Events) without presenting the system prompt.
/// Calling osascript when the user has not allowed control is what previously
/// put DropAgent into an uninterruptible wait on the TCC dialog.
public enum AutomationAccess {
    public static func isAllowed(bundleIdentifier: String) -> Bool {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleIdentifier)
        let status = AEDeterminePermissionToAutomateTarget(
            target.aeDesc,
            typeWildCard,
            typeWildCard,
            false
        )
        return status == noErr
    }
}
