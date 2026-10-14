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

@Test("About info exposes the release store folder and source")
func aboutInfoExposesReleaseStoreFolderAndSource() {
    let info = AboutInfo(
        identity: AppIdentity(
            infoDictionary: [
                "CFBundleDisplayName": "Keyameleon",
                "CFBundleShortVersionString": "1.2.3"
            ]
        ),
        buildIdentity: .release
    )

    #expect(info.repositoryURL.absoluteString == "https://github.com/mastro993/Keyameleon")
    #expect(info.identity.versionLabel == "v1.2.3")
    let legacyConfiguration = ModelConfiguration(
        schema: Schema(versionedSchema: PhysicalKeyboardSchemaV1.self),
        isStoredInMemoryOnly: false
    )
    let releaseConfiguration = SwiftDataPhysicalKeyboardRecordStore.makeConfiguration(buildIdentity: .release)
    let expectedStoreURL = legacyConfiguration.url.deletingLastPathComponent()
        .appending(path: "Keyameleon/default.store")
    #expect(releaseConfiguration.url == expectedStoreURL)
    #expect(releaseConfiguration.url != legacyConfiguration.url)
    #expect(!releaseConfiguration.isStoredInMemoryOnly)
    #expect(info.appDataFolderURL == releaseConfiguration.url.deletingLastPathComponent())
    #expect(info.logsFolderURL.path.hasSuffix("/Library/Logs/Keyameleon"))
}

@Test("About info points a Debug build at its own data and logs folders")
func aboutInfoExposesDebugFolders() {
    let info = AboutInfo(identity: AppIdentity(infoDictionary: [:]), buildIdentity: .debug)
    let legacyConfiguration = ModelConfiguration(
        schema: Schema(versionedSchema: PhysicalKeyboardSchemaV1.self),
        isStoredInMemoryOnly: false
    )
    let debugConfiguration = SwiftDataPhysicalKeyboardRecordStore.makeConfiguration(buildIdentity: .debug)

    #expect(debugConfiguration.url == legacyConfiguration.url.deletingLastPathComponent()
        .appending(path: "Keyameleon Dev/default.store"))
    #expect(info.appDataFolderURL == debugConfiguration.url.deletingLastPathComponent())
    #expect(info.logsFolderURL.path.hasSuffix("/Library/Logs/Keyameleon Dev"))
}

@Test("The Debug test host runs under the Debug identity")
func debugHostUsesDebugIdentity() {
    #expect(Bundle.main.bundleIdentifier == "dev.fedemas.keyameleon.debug")
    #expect(Bundle.main.bundleURL.lastPathComponent == "Keyameleon (Dev).app")
    #expect(AppBuildIdentity.current == .debug)
    #expect(AppIdentity.current.name == "Keyameleon (Dev)")
}
