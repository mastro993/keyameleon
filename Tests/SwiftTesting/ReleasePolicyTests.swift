import Foundation
import Testing
@testable import Keyameleon

@Test("Official Release tags are Semantic Versioning cores with a v prefix")
func officialReleaseTagsRequireStrictSemVer() {
    #expect(KeyameleonReleasePolicy.isOfficialReleaseTag("v0.1.0"))
    #expect(KeyameleonReleasePolicy.isOfficialReleaseTag("v1.2.3"))
    #expect(KeyameleonReleasePolicy.isOfficialReleaseTag("v10.20.30"))

    #expect(!KeyameleonReleasePolicy.isOfficialReleaseTag("1.2.3"))
    #expect(!KeyameleonReleasePolicy.isOfficialReleaseTag("v1.2"))
    #expect(!KeyameleonReleasePolicy.isOfficialReleaseTag("v1.2.3-beta.1"))
    #expect(!KeyameleonReleasePolicy.isOfficialReleaseTag("v1.2.3+build.1"))
    #expect(!KeyameleonReleasePolicy.isOfficialReleaseTag("release-1.2.3"))
    #expect(!KeyameleonReleasePolicy.isOfficialReleaseTag("v01.2.3"))
    #expect(!KeyameleonReleasePolicy.isOfficialReleaseTag(""))
}

@Test("Official Release tag maps to Semantic Versioning core")
func officialReleaseTagMapsToSemanticVersion() {
    #expect(KeyameleonReleasePolicy.semanticVersion(fromOfficialReleaseTag: "v0.1.0") == "0.1.0")
    #expect(KeyameleonReleasePolicy.semanticVersion(fromOfficialReleaseTag: "v2.10.0") == "2.10.0")
    #expect(KeyameleonReleasePolicy.semanticVersion(fromOfficialReleaseTag: "v1.2") == nil)
}

@Test("Release artifact names use product and version")
func releaseArtifactNamesUseProductAndVersion() {
    #expect(
        KeyameleonReleasePolicy.applicationArchiveFileName(version: "1.2.3")
            == "Keyameleon-1.2.3.zip"
    )
    #expect(
        KeyameleonReleasePolicy.sourceArchiveFileName(version: "1.2.3")
            == "Keyameleon-source-1.2.3.tar.gz"
    )
    #expect(KeyameleonReleasePolicy.appcastFileName == "appcast.xml")
    #expect(KeyameleonReleasePolicy.evidenceFileName == "release-evidence.json")
}

@Test("Release policy records GPL-3.0-only and latest-only Supported Release")
func releasePolicyRecordsLicenseAndSupportedBoundary() {
    #expect(KeyameleonReleasePolicy.licenseSPDXIdentifier == "GPL-3.0-only")
    #expect(KeyameleonReleasePolicy.supportedReleaseIsLatestOnly)
}

@Test("Release evidence binds artifact hash to Official Release tag")
func releaseEvidenceBindsArtifactHashToTag() throws {
    let sha =
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    let evidence = try #require(
        KeyameleonReleaseEvidence.make(
            tag: "v1.4.0",
            gitCommit: "abc123def456",
            artifactSHA256: sha
        )
    )

    #expect(evidence.product == "Keyameleon")
    #expect(evidence.licenseSPDXIdentifier == "GPL-3.0-only")
    #expect(evidence.tag == "v1.4.0")
    #expect(evidence.semanticVersion == "1.4.0")
    #expect(evidence.gitCommit == "abc123def456")
    #expect(evidence.artifactFileName == "Keyameleon-1.4.0.zip")
    #expect(evidence.artifactSHA256 == sha)
    #expect(evidence.sourceArchiveFileName == "Keyameleon-source-1.4.0.tar.gz")
    #expect(evidence.appcastFileName == "appcast.xml")
    #expect(evidence.feedURLString == KeyameleonUpdatePolicy.feedURLString)

    let data = try evidence.jsonData()
    let decoded = try JSONDecoder().decode(KeyameleonReleaseEvidence.self, from: data)
    #expect(decoded == evidence)
}

@Test("Release evidence rejects non-Official tags and bad hashes")
func releaseEvidenceRejectsInvalidInputs() {
    let sha =
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    #expect(
        KeyameleonReleaseEvidence.make(
            tag: "1.4.0",
            gitCommit: "abc",
            artifactSHA256: sha
        ) == nil
    )
    #expect(
        KeyameleonReleaseEvidence.make(
            tag: "v1.4.0",
            gitCommit: "",
            artifactSHA256: sha
        ) == nil
    )
    #expect(
        KeyameleonReleaseEvidence.make(
            tag: "v1.4.0",
            gitCommit: "abc",
            artifactSHA256: "not-a-hash"
        ) == nil
    )
}
