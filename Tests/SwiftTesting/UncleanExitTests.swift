import Foundation
import Testing
@testable import Keyameleon

@MainActor
@Test("Unclean launch creates one dismissible local notice")
func uncleanLaunchCreatesOneDismissibleLocalNotice() {
    let suiteName = "Keyameleon.UncleanExitTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let firstLaunch = UserDefaultsUncleanExitStateStore(defaults: defaults)
    firstLaunch.beginLaunch()
    #expect(!firstLaunch.hasPendingUncleanExitNotice)

    let secondLaunch = UserDefaultsUncleanExitStateStore(defaults: defaults)
    secondLaunch.beginLaunch()
    #expect(secondLaunch.hasPendingUncleanExitNotice)

    secondLaunch.dismissUncleanExitNotice()
    #expect(!secondLaunch.hasPendingUncleanExitNotice)
}

@MainActor
@Test("Clean termination does not create an unclean-exit notice")
func cleanTerminationDoesNotCreateUncleanExitNotice() {
    let suiteName = "Keyameleon.UncleanExitTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let store = UserDefaultsUncleanExitStateStore(defaults: defaults)
    store.beginLaunch()
    store.markCleanTermination()

    let nextLaunch = UserDefaultsUncleanExitStateStore(defaults: defaults)
    nextLaunch.beginLaunch()

    #expect(!nextLaunch.hasPendingUncleanExitNotice)
}
