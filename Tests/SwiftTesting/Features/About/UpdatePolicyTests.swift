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
            == "https://mastro993.github.io/keyameleon/appcast.xml"
    )
}
