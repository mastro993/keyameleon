import CryptoKit
import Foundation
import Testing
@testable import Keyameleon

@Test("Application bundle includes complete MIT and Sparkle licenses with third-party notices")
func applicationBundleIncludesCompleteLicensesAndThirdPartyNotices() throws {
    let resources = try #require(Bundle.main.resourceURL)
    let licenses = resources.appending(path: "Licenses", directoryHint: .isDirectory)
    let expectedLicenses = [
        ("LICENSE.txt", "1cbb0d463783a1cca4d56f490cef2586c1432057115e1361f1c944d037ed25da"),
        ("Sparkle-LICENSE.txt", "389a4e4e9a32f059775b13a06e25a591445ba229d2838d26dd3e7c0c45127cfe")
    ]
    for (filename, expectedChecksum) in expectedLicenses {
        let data = try #require(
            try? Data(contentsOf: licenses.appending(path: filename)),
            "Missing bundled license: \(filename)"
        )
        let checksum = SHA256.hash(data: data).map { byte in
            let hex = String(byte, radix: 16)
            return hex.count == 1 ? "0\(hex)" : hex
        }.joined()
        #expect(checksum == expectedChecksum, "Bundled license must preserve complete text: \(filename)")
    }
    let notices = try #require(
        try? Data(contentsOf: licenses.appending(path: "THIRD_PARTY_NOTICES.md")),
        "Missing bundled third-party notices"
    )
    let noticesText = try #require(String(data: notices, encoding: .utf8))
    #expect(!noticesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
}

@Test("Every bundled license the About pane links resolves inside the app bundle")
func bundledLicenseLinksResolveInsideTheAppBundle() throws {
    let licenses = try #require(Bundle.main.resourceURL)
        .appending(path: "Licenses", directoryHint: .isDirectory)
    for license in [KeyameleonBundledLicense.project, .sparkle] {
        let url = try #require(license.url, "Missing bundled license URL: \(license.rawValue)")
        #expect(url.deletingLastPathComponent() == licenses)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }
}
