import Foundation

public enum ClipboardStaging {
    public static func filesToAdmit(
        payload: ClipboardPayload,
        inboxRoot: URL,
        jobsRoot: URL,
        suppress: Bool
    ) -> [URL] {
        guard suppress == false else { return [] }
        guard case .files(let urls) = payload else { return [] }
        return urls.filter { url in
            OwnedCopy.isInside(url, root: inboxRoot) == false
                && OwnedCopy.isInside(url, root: jobsRoot) == false
        }
    }
}
