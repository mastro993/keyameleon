import Foundation

/// macOS posts no notification when Input Monitoring changes, so this polls
/// once a second while permission is missing. It sees the consent alert's
/// answer and any grant macOS applies to the running process.
@MainActor
final class ListenPermissionWatch {
    private var task: Task<Void, Never>?

    /// Starts polling unless already polling. `poll` runs on each tick.
    func start(poll: @escaping @MainActor () -> Void) {
        guard task == nil else {
            return
        }

        task = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                poll()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
