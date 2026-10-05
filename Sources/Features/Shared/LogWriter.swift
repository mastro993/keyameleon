import Foundation

/// Where Keyameleon writes log lines.
///
/// A process starts silent. The live application installs a writer at launch, so
/// hosted unit tests and SwiftUI previews never write to the user's Logs folder.
struct LogWriter: Sendable {
    static let inactive = LogWriter { _, _, _ in }

    private let write: @Sendable (LogLevel, LogCategory, String) -> Void

    init(_ write: @escaping @Sendable (LogLevel, LogCategory, String) -> Void) {
        self.write = write
    }

    static func file(
        directory: URL = AboutInfo.current.logsFolderURL,
        maximumFileByteCount: Int = LogFile.maximumFileByteCount,
        keptRotatedFileCount: Int = LogFile.keptRotatedFileCount
    ) -> LogWriter {
        writer(
            for: LogFile(
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
        directory: URL = AboutInfo.current.logsFolderURL
    ) -> LogWriter {
        writer(for: LogFile(directory: directory, rotates: false))
    }

    func append(_ level: LogLevel, category: LogCategory, message: String) {
        write(level, category, message)
    }

    private static func writer(for file: LogFile) -> LogWriter {
        LogWriter { level, category, message in
            file.append(level, category: category, message: message)
        }
    }
}
