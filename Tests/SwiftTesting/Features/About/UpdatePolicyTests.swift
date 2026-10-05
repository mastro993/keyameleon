import Foundation
import Testing
@testable import Keyameleon

@Test("Update policy bounds checks and forbids auto-install tracking")
func updatePolicyBoundsChecksAndPrivacy() {
    #expect(UpdatePolicy.minimumCheckInterval == 24 * 60 * 60)
    #expect(UpdatePolicy.allowsAutomaticInstallation == false)
    #expect(UpdatePolicy.criticalUpdatesBypassUserApproval == false)
    #expect(UpdatePolicy.allowsAppGeneratedIdentifiers == false)
    #expect(UpdatePolicy.sendsSystemProfile == false)
    #expect(
        UpdatePolicy.feedURLString
            == "https://mastro993.github.io/keyameleon/appcast.xml"
    )
}
