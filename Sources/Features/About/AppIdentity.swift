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

    var versionLabel: String {
        guard version != "—" else {
            return version
        }
        return version.hasPrefix("v") ? version : "v\(version)"
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

struct KeyameleonAboutInfo: Equatable, Sendable {
    let identity: KeyameleonAppIdentity
    let repositoryURL: URL
    let appDataFolderURL: URL
    let logsFolderURL: URL

    static let current = KeyameleonAboutInfo(identity: .current)

    init(identity: KeyameleonAppIdentity) {
        self.init(
            identity: identity,
            repositoryURL: URL(string: "https://github.com/mastro993/Keyameleon")!,
            appDataFolderURL: Self.defaultAppDataFolderURL,
            logsFolderURL: Self.defaultLogsFolderURL
        )
    }

    init(
        identity: KeyameleonAppIdentity,
        repositoryURL: URL,
        appDataFolderURL: URL,
        logsFolderURL: URL
    ) {
        self.identity = identity
        self.repositoryURL = repositoryURL
        self.appDataFolderURL = appDataFolderURL
        self.logsFolderURL = logsFolderURL
    }

    private static var defaultAppDataFolderURL: URL {
        let fileManager = FileManager.default
        let applicationSupportDirectory = fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return applicationSupportDirectory
            .appendingPathComponent("Keyameleon", isDirectory: true)
    }

    private static var defaultLogsFolderURL: URL {
        let libraryDirectory = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return libraryDirectory
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("Keyameleon", isDirectory: true)
    }
}
