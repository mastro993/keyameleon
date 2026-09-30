import Foundation
import SQLite3

enum PhysicalKeyboardStoreMigration {
    static func prepareStore(from legacyURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: destinationURL.path) else {
            return
        }

        for suffix in ["-wal", "-shm"] {
            guard !fileManager.fileExists(atPath: destinationURL.path + suffix) else {
                throw CocoaError(.fileReadCorruptFile)
            }
        }

        let folder = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        guard fileManager.fileExists(atPath: legacyURL.path) else {
            return
        }

        let stagingFolder = folder.appending(path: ".store-migration", directoryHint: .isDirectory)
        if fileManager.fileExists(atPath: stagingFolder.path) {
            try fileManager.removeItem(at: stagingFolder)
        }
        try fileManager.createDirectory(at: stagingFolder, withIntermediateDirectories: false)
        defer { try? fileManager.removeItem(at: stagingFolder) }

        let stagingURL = stagingFolder.appending(path: destinationURL.lastPathComponent)
        // ponytail: the current schema has no external storage; migrate the full store bundle before adding it.
        try copySnapshot(from: legacyURL, to: stagingURL)
        guard !fileManager.fileExists(atPath: stagingURL.path + "-wal") else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try fileManager.moveItem(at: stagingURL, to: destinationURL)
    }

    private static func copySnapshot(from sourceURL: URL, to destinationURL: URL) throws {
        var source: OpaquePointer?
        var destination: OpaquePointer?
        defer {
            if let source { sqlite3_close(source) }
            if let destination { sqlite3_close(destination) }
        }

        let sourceResult = sqlite3_open_v2(sourceURL.path, &source, SQLITE_OPEN_READONLY, nil)
        guard sourceResult == SQLITE_OK, let source else {
            throw NSError(domain: "SQLite", code: Int(sourceResult))
        }
        let destinationResult = sqlite3_open_v2(
            destinationURL.path,
            &destination,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE,
            nil
        )
        guard destinationResult == SQLITE_OK, let destination else {
            throw NSError(domain: "SQLite", code: Int(destinationResult))
        }
        guard let backup = sqlite3_backup_init(destination, "main", source, "main") else {
            throw NSError(domain: "SQLite", code: Int(sqlite3_errcode(destination)))
        }
        let stepResult = sqlite3_backup_step(backup, -1)
        let finishResult = sqlite3_backup_finish(backup)
        guard stepResult == SQLITE_DONE else {
            throw NSError(domain: "SQLite", code: Int(stepResult))
        }
        guard finishResult == SQLITE_OK else {
            throw NSError(domain: "SQLite", code: Int(finishResult))
        }
        let journalResult = sqlite3_exec(destination, "PRAGMA journal_mode=DELETE", nil, nil, nil)
        guard journalResult == SQLITE_OK else {
            throw NSError(domain: "SQLite", code: Int(journalResult))
        }
    }
}
