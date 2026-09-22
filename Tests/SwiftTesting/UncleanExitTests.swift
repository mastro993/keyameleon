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

@Test("Unclean Exit notice opens About only for a pending notice on a launched surface after setup")
func uncleanExitNoticeOpensAboutOnlyForPendingNoticeOnLaunchedSurfaceAfterSetup() {
    for launchCase in UncleanExitLaunchCase.allCases {
        let opensAbout = UncleanExitPresentation.shouldOpenAbout(
            hasPendingNotice: launchCase.hasPendingNotice,
            startsApplicationSurface: launchCase.startsApplicationSurface,
            setupComplete: launchCase.setupComplete
        )

        #expect(opensAbout == launchCase.opensAbout, "\(launchCase)")
    }
}

private struct UncleanExitLaunchCase: CustomStringConvertible {
    let hasPendingNotice: Bool
    let startsApplicationSurface: Bool
    let setupComplete: Bool
    let opensAbout: Bool

    var description: String {
        "pending \(hasPendingNotice), surface \(startsApplicationSurface), setup \(setupComplete)"
    }

    static let allCases: [Self] = [
        Self(hasPendingNotice: true, startsApplicationSurface: true, setupComplete: true, opensAbout: true),
        Self(hasPendingNotice: false, startsApplicationSurface: true, setupComplete: true, opensAbout: false),
        Self(hasPendingNotice: true, startsApplicationSurface: false, setupComplete: true, opensAbout: false),
        Self(hasPendingNotice: true, startsApplicationSurface: true, setupComplete: false, opensAbout: false),
        Self(hasPendingNotice: false, startsApplicationSurface: false, setupComplete: true, opensAbout: false),
        Self(hasPendingNotice: false, startsApplicationSurface: true, setupComplete: false, opensAbout: false),
        Self(hasPendingNotice: true, startsApplicationSurface: false, setupComplete: false, opensAbout: false),
        Self(hasPendingNotice: false, startsApplicationSurface: false, setupComplete: false, opensAbout: false)
    ]
}

@MainActor
@Test("About notice dismiss clears the pending Unclean Exit flag")
func aboutNoticeDismissClearsPendingUncleanExitFlag() {
    let suiteName = "Keyameleon.UncleanExitTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let store = UserDefaultsUncleanExitStateStore(defaults: defaults)
    store.beginLaunch()
    store.beginLaunch()

    let model = KeyameleonGeneralSettingsModel(
        launchAtLoginController: FakeLaunchAtLoginController(isEnabled: false),
        updateChecker: FakeUpdateChecker(canCheck: false),
        uncleanExitStateStore: store
    )

    #expect(model.hasPendingUncleanExitNotice)

    model.dismissUncleanExitNotice()

    #expect(!model.hasPendingUncleanExitNotice)
    #expect(!store.hasPendingUncleanExitNotice)
}
