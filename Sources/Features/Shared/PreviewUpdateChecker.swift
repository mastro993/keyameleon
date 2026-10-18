#if DEBUG
import Foundation

@MainActor
final class PreviewUpdateChecker: UpdateChecking {
    private(set) var canCheckForUpdates: Bool

    init(canCheck: Bool) {
        canCheckForUpdates = canCheck
    }

    func start() {
        canCheckForUpdates = true
    }

    func checkForUpdates() {}
}

#endif
