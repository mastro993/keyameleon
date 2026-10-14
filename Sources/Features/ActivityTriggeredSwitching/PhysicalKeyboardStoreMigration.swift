import Foundation
import SQLite3

enum PhysicalKeyboardStoreMigration {
    /// Creates the store folder and, given a `legacyURL`, imports that store.
    /// Orphan destination sidecars always fail, so a store is never recreated
    /// over unreadable data.
    static func prepareStore(from legacyURL: URL?, to destinationURL: URL) throws {
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
        guard let legacyURL, fileManager.fileExists(atPath: legacyURL.path) else {
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
        // Inspect the snapshot, so the legacy file is opened once and the check sees exactly what would be imported.
        guard try isKeyameleonStore(at: stagingURL) else {
            Log.warning(.app, "Skipped the legacy store because it holds another app's data")
            return
        }
        try fileManager.moveItem(at: stagingURL, to: destinationURL)
    }

    /// Before 0.4.6 the store lived at SwiftData's shared default path, which any other non-sandboxed SwiftData
    /// app can own. A store is Keyameleon's when it has the keyboard table and every other table is Keyameleon's
    /// or Core Data's own; `delete_legacy_store` in `Scripts/run.sh` runs the same query.
    /// A mixed store is skipped too: its model metadata may be the other app's, so SwiftData could fail to
    /// open the copy on every launch, and the copy would carry that app's data into Keyameleon's folder.
    private static let keyameleonStoreQuery = """
        SELECT EXISTS (SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'ZPHYSICALKEYBOARDRECORDMODEL')
            AND NOT EXISTS (SELECT 1 FROM sqlite_master WHERE type = 'table' AND name NOT GLOB 'sqlite_*'
                AND name NOT IN (
                    'ZPHYSICALKEYBOARDRECORDMODEL', 'ZMANUALPHYSICALKEYBOARDDESIGNATIONMODEL',
                    'Z_PRIMARYKEY', 'Z_METADATA', 'Z_MODELCACHE',
                    'ACHANGE', 'ATRANSACTION', 'ATRANSACTIONSTRING'))
        """

    private static func isKeyameleonStore(at url: URL) throws -> Bool {
        var database: OpaquePointer?
        var statement: OpaquePointer?
        defer {
            sqlite3_finalize(statement)
            if let database { sqlite3_close(database) }
        }

        let openResult = sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil)
        guard openResult == SQLITE_OK, let database else {
            throw NSError(domain: "SQLite", code: Int(openResult))
        }
        let prepareResult = sqlite3_prepare_v2(database, keyameleonStoreQuery, -1, &statement, nil)
        guard prepareResult == SQLITE_OK else {
            throw NSError(domain: "SQLite", code: Int(prepareResult))
        }
        let stepResult = sqlite3_step(statement)
        guard stepResult == SQLITE_ROW else {
            throw NSError(domain: "SQLite", code: Int(stepResult))
        }
        return sqlite3_column_int(statement, 0) == 1
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
