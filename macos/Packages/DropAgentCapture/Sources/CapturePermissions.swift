import AppKit
import Foundation

public struct BrowserAutomationRow: Equatable, Sendable {
    public var kind: BrowserFront.Kind
    public var bundleIdentifier: String
    public var installed: Bool
    public var running: Bool
    public var state: AutomationState

    public init(
        kind: BrowserFront.Kind,
        bundleIdentifier: String,
        installed: Bool,
        running: Bool,
        state: AutomationState
    ) {
        self.kind = kind
        self.bundleIdentifier = bundleIdentifier
        self.installed = installed
        self.running = running
        self.state = state
    }

    public var allowed: Bool { state == .allowed }
}

public struct CapturePermissionStatus: Equatable, Sendable {
    public var accessibilityTrusted: Bool
    public var browsers: [BrowserAutomationRow]

    public init(accessibilityTrusted: Bool, browsers: [BrowserAutomationRow]) {
        self.accessibilityTrusted = accessibilityTrusted
        self.browsers = browsers
    }

    public var captureReady: Bool {
        accessibilityTrusted && browsers.allSatisfy(\.allowed)
    }
}

public enum CapturePermissions {
    public static func status(
        accessibilityTrusted: Bool,
        installedBundleIDs: Set<String>,
        runningBundleIDs: Set<String>,
        stateForBundle: (String) -> AutomationState
    ) -> CapturePermissionStatus {
        let installedLower = Set(installedBundleIDs.map { $0.lowercased() })
        let runningLower = Set(runningBundleIDs.map { $0.lowercased() })
        var rows: [BrowserAutomationRow] = []
        for kind in BrowserFront.Kind.appleScriptCases {
            let knownLower = kind.knownBundleIdentifiers.map { $0.lowercased() }
            guard knownLower.contains(where: { installedLower.contains($0) }) else { continue }
            let runningNow = knownLower.contains(where: { runningLower.contains($0) })
            let target = pickBundle(
                kind: kind,
                preferred: runningNow ? runningBundleIDs : [],
                fallback: installedBundleIDs
            )
            let probed = stateForBundle(target)
            let state: AutomationState
            if runningNow == false && probed != .allowed {
                state = .unavailable
            } else {
                state = probed
            }
            rows.append(
                BrowserAutomationRow(
                    kind: kind,
                    bundleIdentifier: target,
                    installed: true,
                    running: runningNow,
                    state: state
                )
            )
        }
        return CapturePermissionStatus(accessibilityTrusted: accessibilityTrusted, browsers: rows)
    }

    public static func pickBundle(
        kind: BrowserFront.Kind,
        preferred: Set<String>,
        fallback: Set<String>
    ) -> String {
        for known in kind.knownBundleIdentifiers {
            let lower = known.lowercased()
            if let live = preferred.first(where: { $0.lowercased() == lower }) {
                return live
            }
        }
        for known in kind.knownBundleIdentifiers {
            let lower = known.lowercased()
            if let live = fallback.first(where: { $0.lowercased() == lower }) {
                return live
            }
        }
        return kind.primaryBundleIdentifier
    }

    public static func liveStatus() -> CapturePermissionStatus {
        status(
            accessibilityTrusted: AccessibilityPage.isTrusted(),
            installedBundleIDs: liveInstalledBundleIDs(),
            runningBundleIDs: liveRunningBundleIDs(),
            stateForBundle: { AutomationAccess.probe(bundleIdentifier: $0) }
        )
    }

    public static func liveInstalledBundleIDs() -> Set<String> {
        var ids: Set<String> = [BrowserFront.Kind.safari.primaryBundleIdentifier]
        for kind in BrowserFront.Kind.appleScriptCases {
            for bundle in kind.knownBundleIdentifiers {
                if NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) != nil {
                    ids.insert(bundle)
                }
            }
        }
        return ids
    }

    public static func liveRunningBundleIDs() -> Set<String> {
        Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
    }
}
