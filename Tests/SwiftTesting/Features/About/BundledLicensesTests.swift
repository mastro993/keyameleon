import CryptoKit
import Foundation
import Testing

@Test("Application bundle includes complete GPL and Sparkle licenses with third-party notices")
func applicationBundleIncludesCompleteLicensesAndThirdPartyNotices() throws {
    let resources = try #require(Bundle.main.resourceURL)
    let licenses = resources.appending(path: "Licenses", directoryHint: .isDirectory)
    let expectedLicenses = [
        ("LICENSE.txt", "605e9047a563c5c8396ffb18232aa4304ec56586aee537c45064c6fb425e44ad"),
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
