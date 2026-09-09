import AppKit
import DropAgentCapture
import Foundation

public enum FrontAdmitKind: Equatable, Sendable {
    case finder
    case browser
    case `self`
    case other
}

public enum FrontAdmitError: Equatable, Sendable, Error {
    case selfApp
    case browser
    case needAccessibility
    case needFinderAutomation
    case emptyFinder
    case empty
}

public struct FrontAdmitRead: Equatable, Sendable {
    public var urls: [URL]

    public init(urls: [URL]) {
        self.urls = urls
    }
}

public enum FrontAdmit {
    public static var finderBundleID: String { FrontFiles.finderBundleID }

    public static func classify(
        bundleID: String?,
        selfBundle: String = Bundle.main.bundleIdentifier ?? "local.dropagent"
    ) -> FrontAdmitKind {
        wrap(FrontFiles.classify(bundleID: bundleID, selfBundle: selfBundle))
    }

    public static func decide(
        kind: FrontAdmitKind,
        axTrusted: Bool,
        finderAllowed: Bool
    ) -> Result<Void, FrontAdmitError> {
        map(FrontFiles.decide(kind: unwrap(kind), axTrusted: axTrusted, finderAllowed: finderAllowed))
    }

    public static func finderAllowedOffMain() async -> Bool {
        await PermissionWork.run { finderAllowed() }
    }

    public static func finderAllowed() -> Bool {
        AutomationAccess.isAllowed(bundleIdentifier: FrontFiles.finderBundleID)
    }

    public static func finderRow() -> PageAdmitBrowserRow {
        let running = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier?.caseInsensitiveCompare(FrontFiles.finderBundleID) == .orderedSame
        }
        return PageAdmitBrowserRow(
            displayName: "Finder",
            bundleIdentifier: FrontFiles.finderBundleID,
            running: running,
            state: PageAdmitAutomation(AutomationAccess.probe(bundleIdentifier: FrontFiles.finderBundleID))
        )
    }

    @MainActor
    public static func collect(
        frontBundleID: String?,
        frontPID: pid_t,
        selfBundle: String = Bundle.main.bundleIdentifier ?? "local.dropagent"
    ) async -> Result<FrontAdmitRead, FrontAdmitError> {
        switch await FrontFiles.collect(
            frontBundleID: frontBundleID,
            frontPID: frontPID,
            selfBundle: selfBundle
        ) {
        case .success(let read):
            return .success(FrontAdmitRead(urls: read.urls))
        case .failure(let fail):
            return .failure(wrap(fail))
        }
    }

    private static func wrap(_ kind: FrontFileKind) -> FrontAdmitKind {
        switch kind {
        case .finder: return .finder
        case .browser: return .browser
        case .self: return .self
        case .other: return .other
        }
    }

    private static func unwrap(_ kind: FrontAdmitKind) -> FrontFileKind {
        switch kind {
        case .finder: return .finder
        case .browser: return .browser
        case .self: return .self
        case .other: return .other
        }
    }

    private static func wrap(_ fail: FrontFileFailure) -> FrontAdmitError {
        switch fail {
        case .selfApp: return .selfApp
        case .browser: return .browser
        case .needAccessibility: return .needAccessibility
        case .needFinderAutomation: return .needFinderAutomation
        case .emptyFinder: return .emptyFinder
        case .empty: return .empty
        }
    }

    private static func map(_ result: Result<Void, FrontFileFailure>) -> Result<Void, FrontAdmitError> {
        switch result {
        case .success: return .success(())
        case .failure(let fail): return .failure(wrap(fail))
        }
    }
}
