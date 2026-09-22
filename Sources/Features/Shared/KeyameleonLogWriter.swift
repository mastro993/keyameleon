import Foundation

/// Where Keyameleon writes log lines.
///
/// A process starts silent. The live application installs a writer at launch, so
/// hosted unit tests and SwiftUI previews never write to the user's Logs folder.
struct KeyameleonLogWriter: Sendable {
    static let inactive = KeyameleonLogWriter { _, _, _ in }

    private let write: @Sendable (KeyameleonLogLevel, KeyameleonLogCategory, String) -> Void

    init(_ write: @escaping @Sendable (KeyameleonLogLevel, KeyameleonLogCategory, String) -> Void) {
        self.write = write
    }

    static func file(
        directory: URL = KeyameleonAboutInfo.current.logsFolderURL,
        maximumFileByteCount: Int = KeyameleonLogFile.maximumFileByteCount,
        keptRotatedFileCount: Int = KeyameleonLogFile.keptRotatedFileCount
    ) -> KeyameleonLogWriter {
        writer(
            for: KeyameleonLogFile(
                directory: directory,
                maximumFileByteCount: maximumFileByteCount,
                keptRotatedFileCount: keptRotatedFileCount,
                rotates: true
            )
        )
    }

    /// Appends to the active file and never rotates it. The single-instance exit
    /// path uses this, because renaming a file another process holds open would
    /// send that process's later lines into a rotated file.
    static func appendOnlyFile(
        directory: URL = KeyameleonAboutInfo.current.logsFolderURL
    ) -> KeyameleonLogWriter {
        writer(for: KeyameleonLogFile(directory: directory, rotates: false))
    }

    func append(_ level: KeyameleonLogLevel, category: KeyameleonLogCategory, message: String) {
        write(level, category, message)
    }

    private static func writer(for file: KeyameleonLogFile) -> KeyameleonLogWriter {
        KeyameleonLogWriter { level, category, message in
            file.append(level, category: category, message: message)
        }
    }
}
