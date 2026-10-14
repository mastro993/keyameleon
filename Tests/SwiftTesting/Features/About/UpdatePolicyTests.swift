import Foundation
import Testing
@testable import Keyameleon

@Test("Builds without the Official Release EdDSA key keep update checks unavailable")
@MainActor
func keylessBuildUpdaterDoesNotStart() throws {
    try #require(Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") == nil)
    let checker = SparkleUpdateChecker()
    checker.start()
    checker.checkForUpdates()
    #expect(!checker.canCheckForUpdates)
}

@Test("Update policy bounds checks and keeps system profiling off")
func updatePolicyBoundsChecksAndPrivacy() {
    #expect(UpdatePolicy.minimumCheckInterval == 24 * 60 * 60)
    #expect(UpdatePolicy.sendsSystemProfile == false)
    #expect(
        UpdatePolicy.feedURLString
            == "https://mastro993.github.io/keyameleon/appcast.xml"
    )
}
