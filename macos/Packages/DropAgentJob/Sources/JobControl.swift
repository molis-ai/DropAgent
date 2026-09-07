import Foundation
import os

final class JobControl: @unchecked Sendable {
    private let cancelled = OSAllocatedUnfairLock(initialState: false)

    func begin() {
        cancelled.withLock { $0 = false }
    }

    func markCancelled() {
        cancelled.withLock { $0 = true }
    }

    func end() {
        cancelled.withLock { $0 = false }
    }

    var isCancelled: Bool {
        cancelled.withLock { $0 }
    }
}
