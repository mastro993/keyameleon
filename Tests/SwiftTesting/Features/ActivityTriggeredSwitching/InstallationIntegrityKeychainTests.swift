import Foundation
import Security
import Testing
@testable import Keyameleon

@Test("Data-protection queries keep the installation integrity key on this device")
func dataProtectionQueriesKeepKeyOnThisDevice() {
    let queries = [
        InstallationIntegrityKeyQuery.dataProtectionCopy(),
        InstallationIntegrityKeyQuery.dataProtectionAdd(data: Data([0x01])),
        InstallationIntegrityKeyQuery.dataProtectionDelete()
    ]

    for query in queries {
        #expect(query[kSecUseDataProtectionKeychain as String] as? Bool == true)
        #expect(query[kSecAttrSynchronizable as String] as? Bool == false)
    }
}

@Test("Data-protection add pins accessibility for a key a restore must not carry")
func dataProtectionAddPinsAccessibility() {
    let query = InstallationIntegrityKeyQuery.dataProtectionAdd(data: Data([0x01]))

    #expect(
        (query[kSecAttrAccessible as String] as? String)
            == (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    )
}

@Test("Legacy queries still match the login-keychain item")
func legacyQueriesMatchLoginKeychainItem() {
    #expect(
        InstallationIntegrityKeyQuery.legacyCopy()
            .keys.contains(kSecUseDataProtectionKeychain as String) == false
    )
    #expect(
        InstallationIntegrityKeyQuery.legacyDelete()
            .keys.contains(kSecUseDataProtectionKeychain as String) == false
    )
}

@Test("Migration prefers the data-protection item, then the legacy item")
func migrationStepPrefersExistingKeys() {
    #expect(
        InstallationIntegrityKeyMigration.step(dataProtectionItemFound: true, legacyItemFound: true)
            == .useDataProtectionItem
    )
    #expect(
        InstallationIntegrityKeyMigration.step(dataProtectionItemFound: false, legacyItemFound: true)
            == .migrateLegacyItem
    )
    #expect(
        InstallationIntegrityKeyMigration.step(dataProtectionItemFound: false, legacyItemFound: false)
            == .generateNew
    )
}
