import Foundation
import Testing
@testable import Keyameleon

@Test("Only the release bundle identifier keeps the release storage folder", arguments: [
    ("dev.fedemas.keyameleon", AppBuildIdentity.release, "Keyameleon"),
    ("dev.fedemas.keyameleon.debug", AppBuildIdentity.debug, "Keyameleon Dev"),
    ("dev.fedemas.keyameleon.development", AppBuildIdentity.debug, "Keyameleon Dev"),
    ("", AppBuildIdentity.debug, "Keyameleon Dev")
])
func storageFolderFollowsBundleIdentifier(
    bundleIdentifier: String,
    identity: AppBuildIdentity,
    folderName: String
) {
    let resolved = AppBuildIdentity(bundleIdentifier: bundleIdentifier)
    #expect(resolved == identity)
    #expect(resolved.storageFolderName == folderName)
    #expect(AppBuildIdentity(bundleIdentifier: nil) == .debug)
}

@Test("Only the release imports the legacy store")
func onlyReleaseImportsLegacyStore() {
    #expect(AppBuildIdentity.release.importsLegacyStore)
    #expect(!AppBuildIdentity.debug.importsLegacyStore)
}
