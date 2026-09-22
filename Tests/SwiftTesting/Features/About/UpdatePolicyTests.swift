import Foundation
import Testing
@testable import Keyameleon

@Test("Update policy bounds checks and forbids auto-install tracking")
func updatePolicyBoundsChecksAndPrivacy() {
    #expect(KeyameleonUpdatePolicy.minimumCheckInterval == 24 * 60 * 60)
    #expect(KeyameleonUpdatePolicy.allowsAutomaticInstallation == false)
    #expect(KeyameleonUpdatePolicy.criticalUpdatesBypassUserApproval == false)
    #expect(KeyameleonUpdatePolicy.allowsKeyameleonGeneratedIdentifiers == false)
    #expect(KeyameleonUpdatePolicy.sendsSystemProfile == false)
    #expect(
        KeyameleonUpdatePolicy.feedURLString
            == "https://mastro993.github.io/Keyameleon/appcast.xml"
    )
}

@Test("Update policy allows a check when none has run")
func updatePolicyAllowsFirstCheck() {
    #expect(KeyameleonUpdatePolicy.shouldCheckForUpdates(lastCheckDate: nil))
}

@Test("Update policy blocks a check inside the 24-hour window")
func updatePolicyBlocksCheckInsideWindow() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let lastCheck = now.addingTimeInterval(-12 * 60 * 60)

    #expect(
        KeyameleonUpdatePolicy.shouldCheckForUpdates(
            lastCheckDate: lastCheck,
            now: now
        ) == false
    )
}

@Test("Update policy allows a check at or after 24 hours")
func updatePolicyAllowsCheckAfterWindow() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let lastCheck = now.addingTimeInterval(-24 * 60 * 60)

    #expect(
        KeyameleonUpdatePolicy.shouldCheckForUpdates(
            lastCheckDate: lastCheck,
            now: now
        )
    )
}
