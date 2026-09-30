import Foundation
@preconcurrency import SwiftData
import Testing
@testable import Keyameleon

@Test("App identity falls back when bundle keys are missing")
func appIdentityFallsBackWhenBundleKeysAreMissing() {
    let identity = KeyameleonAppIdentity(infoDictionary: [:])
    #expect(identity.name == "Keyameleon")
    #expect(identity.version == "—")
}

@Test("App identity trims empty bundle strings as absent")
func appIdentityTrimsEmptyBundleStringsAsAbsent() {
    let identity = KeyameleonAppIdentity(
        infoDictionary: [
            "CFBundleDisplayName": "  ",
            "CFBundleName": "Fallback",
            "CFBundleShortVersionString": "\n",
        ]
    )
    #expect(identity.name == "Fallback")
    #expect(identity.version == "—")
}

@Test("App identity prefers display name and short version")
func appIdentityPrefersDisplayNameAndShortVersion() {
    let identity = KeyameleonAppIdentity(
        infoDictionary: [
            "CFBundleDisplayName": "Shown",
            "CFBundleName": "Hidden",
            "CFBundleShortVersionString": "1.2.3",
        ]
    )
    #expect(identity.name == "Shown")
    #expect(identity.version == "1.2.3")
    #expect(identity.versionLabel == "v1.2.3")
}

@Test("About info exposes the production store folder and source")
func aboutInfoExposesProductionStoreFolderAndSource() {
    let info = KeyameleonAboutInfo(
        identity: KeyameleonAppIdentity(
            infoDictionary: [
                "CFBundleDisplayName": "Keyameleon",
                "CFBundleShortVersionString": "1.2.3",
            ]
        )
    )

    #expect(info.repositoryURL.absoluteString == "https://github.com/mastro993/Keyameleon")
    #expect(info.identity.versionLabel == "v1.2.3")
    let legacyConfiguration = ModelConfiguration(
        schema: Schema(versionedSchema: PhysicalKeyboardSchemaV1.self),
        isStoredInMemoryOnly: false
    )
    #expect(info.appDataFolderURL == legacyConfiguration.url.deletingLastPathComponent())
    #expect(info.logsFolderURL.path.hasSuffix("/Library/Logs/Keyameleon"))
}
