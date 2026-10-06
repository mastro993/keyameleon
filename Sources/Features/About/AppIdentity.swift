import Foundation

struct AppIdentity: Equatable, Sendable {
    let name: String
    let version: String
    let build: String

    static let current = AppIdentity(bundle: .main)

    init(bundle: Bundle) {
        self.init(
            displayName: bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
            bundleName: bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
            shortVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
    }

    init(infoDictionary: [String: Any]?) {
        self.init(
            displayName: infoDictionary?["CFBundleDisplayName"] as? String,
            bundleName: infoDictionary?["CFBundleName"] as? String,
            shortVersion: infoDictionary?["CFBundleShortVersionString"] as? String,
            build: infoDictionary?["CFBundleVersion"] as? String
        )
    }

    var versionLabel: String {
        guard version != "—" else {
            return version
        }
        return version.hasPrefix("v") ? version : "v\(version)"
    }

    /// The version the Settings About pane shows: short version and build.
    var aboutVersionLabel: String {
        guard version != "—", build != "—" else {
            return version
        }
        return "\(version) (\(build))"
    }

    private init(displayName: String?, bundleName: String?, shortVersion: String?, build: String?) {
        name = Self.nonemptyString(displayName)
            ?? Self.nonemptyString(bundleName)
            ?? "Keyameleon"
        version = Self.nonemptyString(shortVersion) ?? "—"
        self.build = Self.nonemptyString(build) ?? "—"
    }

    private static func nonemptyString(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct AboutInfo: Equatable, Sendable {
    /// Keyameleon's public repository, as the About pane links it.
    static let repositoryURL = URL(string: "https://github.com/mastro993/Keyameleon")!
    static let creatorURL = URL(string: "https://x.com/fedemas")!

    let identity: AppIdentity
    let repositoryURL: URL
    let appDataFolderURL: URL
    let logsFolderURL: URL

    static let current = AboutInfo(identity: .current)

    init(identity: AppIdentity, buildIdentity: AppBuildIdentity = .current) {
        self.init(
            identity: identity,
            repositoryURL: Self.repositoryURL,
            appDataFolderURL: SwiftDataPhysicalKeyboardRecordStore
                .makeConfiguration(buildIdentity: buildIdentity).url.deletingLastPathComponent(),
            logsFolderURL: Self.logsFolderURL(buildIdentity: buildIdentity)
        )
    }

    init(
        identity: AppIdentity,
        repositoryURL: URL,
        appDataFolderURL: URL,
        logsFolderURL: URL
    ) {
        self.identity = identity
        self.repositoryURL = repositoryURL
        self.appDataFolderURL = appDataFolderURL
        self.logsFolderURL = logsFolderURL
    }

    private static func logsFolderURL(buildIdentity: AppBuildIdentity) -> URL {
        let libraryDirectory = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return libraryDirectory
            .appendingPathComponent("Logs", isDirectory: true)
            .appending(path: buildIdentity.storageFolderName, directoryHint: .isDirectory)
    }
}
