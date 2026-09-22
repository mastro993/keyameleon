import Foundation

/// The Diagnostic Data store that local logging replaced.
///
/// An upgrade leaves its files in Application Support with no in-app path to
/// remove them, so the app deletes them once at launch.
enum KeyameleonLegacyDiagnosticData {
    static let storeFileNames = [
        "DiagnosticData.store",
        "DiagnosticData.store-shm",
        "DiagnosticData.store-wal"
    ]

    static var defaultDirectoryURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Keyameleon", directoryHint: .isDirectory)
    }

    static func removeStoreFiles(in directory: URL = defaultDirectoryURL) {
        for fileName in storeFileNames {
            try? FileManager.default.removeItem(at: directory.appending(path: fileName))
        }
    }
}
