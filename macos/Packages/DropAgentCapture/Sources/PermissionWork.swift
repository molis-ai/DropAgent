import Foundation

/// Serial blocking system permission work, always outside the UI/cooperative executor.
public enum PermissionWork {
    private static let queue = DispatchQueue(label: "local.dropagent.permissions", qos: .userInitiated)

    public static func run<T: Sendable>(_ operation: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: operation()) }
        }
    }
}
