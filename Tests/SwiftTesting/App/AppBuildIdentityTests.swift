import Foundation
import Testing
@testable import Keyameleon

@Test("Production and development use separate app-owned resources")
func buildIdentitiesSeparateResources() {
    #expect(AppBuildIdentity.production.storageFolderName == "Keyameleon")
    #expect(AppBuildIdentity.development.storageFolderName == "Keyameleon (Dev)")
    #expect(AppBuildIdentity.production.singletonURL.path == "/dev/null")
    #expect(AppBuildIdentity.development.singletonURL.path == "/dev/zero")
    #expect(AppBuildIdentity.production.integrityKeyService
        == "dev.fedemas.keyameleon.installation-integrity")
    #expect(AppBuildIdentity.development.integrityKeyService
        == "dev.fedemas.keyameleon.development.installation-integrity")
    #expect(AppBuildIdentity.production.importsLegacyStore)
    #expect(!AppBuildIdentity.development.importsLegacyStore)
    #expect(AppBuildIdentity.production.allowsUpdates)
    #expect(!AppBuildIdentity.development.allowsUpdates)
}

@Test("Built development app has the native defaults domain and visible name")
func builtDevelopmentAppHasSeparateBundleIdentity() {
    #expect(Bundle.main.bundleIdentifier == "dev.fedemas.keyameleon.development")
    #expect(Bundle.main.bundleIdentifier != "dev.fedemas.keyameleon")
    #expect(AppBuildIdentity.current == .development)
    #expect(AppIdentity.current.name == "Keyameleon (Dev)")
}
