import Foundation
import os

final class JobControl: @unchecked Sendable {
    private struct State { var running = false; var cancelled = false }
    private let state = OSAllocatedUnfairLock(initialState: State())

    func begin() -> Bool {
        state.withLock {
            guard !$0.running else { return false }
            $0.running = true
            $0.cancelled = false
            return true
        }
    }

    func markCancelled() { state.withLock { $0.cancelled = true } }
    func end() { state.withLock { $0 = State() } }
    var isCancelled: Bool { state.withLock { $0.cancelled } }
}
