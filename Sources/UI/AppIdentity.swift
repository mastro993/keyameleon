import Foundation

struct KeyameleonAppIdentity: Equatable, Sendable {
    let name: String
    let version: String

    static let current = KeyameleonAppIdentity(bundle: .main)

    init(bundle: Bundle) {
        self.init(
            displayName: bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
            bundleName: bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
            shortVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        )
    }

    init(infoDictionary: [String: Any]?) {
        self.init(
            displayName: infoDictionary?["CFBundleDisplayName"] as? String,
            bundleName: infoDictionary?["CFBundleName"] as? String,
            shortVersion: infoDictionary?["CFBundleShortVersionString"] as? String
        )
    }

    private init(displayName: String?, bundleName: String?, shortVersion: String?) {
        name = Self.nonemptyString(displayName)
            ?? Self.nonemptyString(bundleName)
            ?? "Keyameleon"
        version = Self.nonemptyString(shortVersion) ?? "—"
    }

    private static func nonemptyString(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
