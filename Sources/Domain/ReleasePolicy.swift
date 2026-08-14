import Foundation

/// Product rules for Official Release tags, evidence, and Supported Release boundary.
enum KeyameleonReleasePolicy {
    /// SPDX identifier for V1 distribution.
    static let licenseSPDXIdentifier = "GPL-3.0-only"

    /// Only the latest Official Release receives maintenance.
    static let supportedReleaseIsLatestOnly = true

    /// Artifact basename published for the Stable Channel on GitHub Releases.
    static let applicationArchiveNamePrefix = "Keyameleon"

    /// Sparkle feed filename published next to the archive.
    static let appcastFileName = "appcast.xml"

    /// Evidence filename that binds artifact hash to source tag.
    static let evidenceFileName = "release-evidence.json"

    /// Source archive attachment name pattern used on GitHub Releases.
    static let sourceArchiveNamePrefix = "Keyameleon-source"

    /// Returns the Semantic Versioning core string when `tag` is an Official Release tag.
    ///
    /// Official Release tags use a leading `v` plus Semantic Versioning 2.0.0 core
    /// (MAJOR.MINOR.PATCH). Pre-release and build metadata are not Official Release tags.
    static func semanticVersion(fromOfficialReleaseTag tag: String) -> String? {
        // Local regex avoids storing non-Sendable Regex in a static property under Swift 6.
        let pattern = /^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/
        guard let match = tag.wholeMatch(of: pattern) else {
            return nil
        }
        return String(match.1) + "." + String(match.2) + "." + String(match.3)
    }

    /// True when `tag` can start the Official Release workflow.
    static func isOfficialReleaseTag(_ tag: String) -> Bool {
        semanticVersion(fromOfficialReleaseTag: tag) != nil
    }

    /// Zip name for a given Semantic Versioning core string.
    static func applicationArchiveFileName(version: String) -> String {
        "\(applicationArchiveNamePrefix)-\(version).zip"
    }

    /// Source archive name for a given Semantic Versioning core string.
    static func sourceArchiveFileName(version: String) -> String {
        "\(sourceArchiveNamePrefix)-\(version).tar.gz"
    }
}

/// Release evidence that connects a published artifact hash to its public source tag.
struct KeyameleonReleaseEvidence: Equatable, Codable, Sendable {
    var product: String
    var licenseSPDXIdentifier: String
    var tag: String
    var semanticVersion: String
    var gitCommit: String
    var artifactFileName: String
    var artifactSHA256: String
    var sourceArchiveFileName: String
    var appcastFileName: String
    var feedURLString: String

    init(
        product: String = "Keyameleon",
        licenseSPDXIdentifier: String = KeyameleonReleasePolicy.licenseSPDXIdentifier,
        tag: String,
        semanticVersion: String,
        gitCommit: String,
        artifactFileName: String,
        artifactSHA256: String,
        sourceArchiveFileName: String,
        appcastFileName: String = KeyameleonReleasePolicy.appcastFileName,
        feedURLString: String = KeyameleonUpdatePolicy.feedURLString
    ) {
        self.product = product
        self.licenseSPDXIdentifier = licenseSPDXIdentifier
        self.tag = tag
        self.semanticVersion = semanticVersion
        self.gitCommit = gitCommit
        self.artifactFileName = artifactFileName
        self.artifactSHA256 = artifactSHA256
        self.sourceArchiveFileName = sourceArchiveFileName
        self.appcastFileName = appcastFileName
        self.feedURLString = feedURLString
    }

    /// Builds evidence only for an Official Release tag with a non-empty commit and SHA-256.
    static func make(
        tag: String,
        gitCommit: String,
        artifactSHA256: String
    ) -> KeyameleonReleaseEvidence? {
        guard let semanticVersion = KeyameleonReleasePolicy.semanticVersion(fromOfficialReleaseTag: tag)
        else {
            return nil
        }
        guard !gitCommit.isEmpty, isSHA256Hex(artifactSHA256) else {
            return nil
        }

        return KeyameleonReleaseEvidence(
            tag: tag,
            semanticVersion: semanticVersion,
            gitCommit: gitCommit,
            artifactFileName: KeyameleonReleasePolicy.applicationArchiveFileName(
                version: semanticVersion
            ),
            artifactSHA256: artifactSHA256.lowercased(),
            sourceArchiveFileName: KeyameleonReleasePolicy.sourceArchiveFileName(
                version: semanticVersion
            )
        )
    }

    /// Pretty-printed JSON for the public evidence attachment.
    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    private static func isSHA256Hex(_ value: String) -> Bool {
        guard value.count == 64 else {
            return false
        }
        return value.allSatisfy(\.isHexDigit)
    }
}
