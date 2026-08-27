import Foundation

@MainActor
protocol UncleanExitStateStoring: AnyObject {
    var hasPendingUncleanExitNotice: Bool { get }

    func beginLaunch()
    func markCleanTermination()
    func dismissUncleanExitNotice()
}

@MainActor
final class UserDefaultsUncleanExitStateStore: UncleanExitStateStoring {
    private enum Key {
        static let activeLaunch = "keyameleon.lifecycle.activeLaunch"
        static let pendingNotice = "keyameleon.lifecycle.pendingUncleanExitNotice"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasPendingUncleanExitNotice: Bool {
        defaults.bool(forKey: Key.pendingNotice)
    }

    func beginLaunch() {
        if defaults.bool(forKey: Key.activeLaunch) {
            defaults.set(true, forKey: Key.pendingNotice)
        }
        defaults.set(true, forKey: Key.activeLaunch)
    }

    func markCleanTermination() {
        defaults.removeObject(forKey: Key.activeLaunch)
    }

    func dismissUncleanExitNotice() {
        defaults.removeObject(forKey: Key.pendingNotice)
    }
}
