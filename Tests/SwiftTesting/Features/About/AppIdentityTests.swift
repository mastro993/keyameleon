import Foundation
@preconcurrency import SwiftData
import Testing
@testable import Keyameleon

@Test("App identity falls back when bundle keys are missing")
func appIdentityFallsBackWhenBundleKeysAreMissing() {
    let identity = AppIdentity(infoDictionary: [:])
    #expect(identity.name == "Keyameleon")
    #expect(identity.version == "—")
}

@Test("App identity trims empty bundle strings as absent")
func appIdentityTrimsEmptyBundleStringsAsAbsent() {
    let identity = AppIdentity(
        infoDictionary: [
            "CFBundleDisplayName": "  ",
            "CFBundleName": "Fallback",
            "CFBundleShortVersionString": "\n"
        ]
    )
    #expect(identity.name == "Fallback")
    #expect(identity.version == "—")
}

@Test("App identity prefers display name and short version")
func appIdentityPrefersDisplayNameAndShortVersion() {
    let identity = AppIdentity(
        infoDictionary: [
            "CFBundleDisplayName": "Shown",
            "CFBundleName": "Hidden",
            "CFBundleShortVersionString": "1.2.3",
            "CFBundleVersion": "7"
        ]
    )
    #expect(identity.name == "Shown")
    #expect(identity.version == "1.2.3")
    #expect(identity.build == "7")
    #expect(identity.versionLabel == "v1.2.3")
    #expect(identity.aboutVersionLabel == "1.2.3 (7)")
}

@Test("About version label falls back when the build number is missing")
func aboutVersionLabelFallsBackToShortVersion() {
    let labeled = AppIdentity(
        infoDictionary: [
            "CFBundleDisplayName": "Keyameleon",
            "CFBundleShortVersionString": "1.2.3"
        ]
    )
    #expect(labeled.aboutVersionLabel == "1.2.3")

    let unknown = AppIdentity(infoDictionary: [:])
    #expect(unknown.aboutVersionLabel == "—")
}

@Test("About info exposes the production store folder and source")
func aboutInfoExposesProductionStoreFolderAndSource() {
    let info = AboutInfo(
        identity: AppIdentity(
            infoDictionary: [
                "CFBundleDisplayName": "Keyameleon",
                "CFBundleShortVersionString": "1.2.3"
            ]
        ),
        buildIdentity: .production
    )

    #expect(info.repositoryURL.absoluteString == "https://github.com/mastro993/Keyameleon")
    #expect(info.identity.versionLabel == "v1.2.3")
    let legacyConfiguration = ModelConfiguration(
        schema: Schema(versionedSchema: PhysicalKeyboardSchemaV1.self),
        isStoredInMemoryOnly: false
    )
    let productionConfiguration = SwiftDataPhysicalKeyboardRecordStore.makeConfiguration(
        buildIdentity: .production
    )
    let expectedStoreURL = legacyConfiguration.url.deletingLastPathComponent()
        .appending(path: "Keyameleon/default.store")
    #expect(productionConfiguration.url == expectedStoreURL)
    #expect(productionConfiguration.url != legacyConfiguration.url)
    #expect(!productionConfiguration.isStoredInMemoryOnly)
    #expect(info.appDataFolderURL == productionConfiguration.url.deletingLastPathComponent())
    #expect(info.logsFolderURL.path.hasSuffix("/Library/Logs/Keyameleon"))
}

@Test("About info points to development data and logs")
func aboutInfoExposesDevelopmentFolders() {
    let info = AboutInfo(identity: AppIdentity(infoDictionary: [:]), buildIdentity: .development)
    #expect(info.appDataFolderURL.lastPathComponent == "Keyameleon (Dev)")
    #expect(info.logsFolderURL.path.hasSuffix("/Library/Logs/Keyameleon (Dev)"))
}
