import Foundation
import Synchronization
import Testing
@testable import Keyameleon

@Test("Every level writes one line with its category and message")
func everyLevelWritesOneLineWithItsCategoryAndMessage() throws {
    let directory = temporaryLogDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let writer = KeyameleonLogWriter.file(directory: directory)

    writer.append(.verbose, category: .app, message: "Coalesced")
    writer.append(.debug, category: .switching, message: "Selected Input Source")
    writer.append(.warning, category: .switching, message: "Could not select Input Source")
    writer.append(.error, category: .setup, message: "Records could not be opened")

    let lines = try logLines(in: directory)
    #expect(lines.count == 4)
    #expect(lines[0].hasSuffix("[verbose] [app] Coalesced"))
    #expect(lines[1].hasSuffix("[debug] [switching] Selected Input Source"))
    #expect(lines[2].hasSuffix("[warning] [switching] Could not select Input Source"))
    #expect(lines[3].hasSuffix("[error] [setup] Records could not be opened"))

    let year = String(currentTimestamp.prefix(4))
    #expect(lines[0].hasPrefix(year))
}

@Test("Log file rotates at the size limit and keeps the newest rotated files")
func logFileRotatesAtTheSizeLimitAndKeepsTheNewestRotatedFiles() throws {
    let directory = temporaryLogDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let writer = KeyameleonLogWriter.file(
        directory: directory,
        maximumFileByteCount: 120,
        keptRotatedFileCount: 2
    )

    for index in 1...12 {
        writer.append(.debug, category: .app, message: "Line \(index)")
    }

    let names = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    #expect(names == ["keyameleon.1.log", "keyameleon.2.log", "keyameleon.log"])
    #expect(try logLines(in: directory).last?.hasSuffix("Line 12") == true)
    #expect(try logLines(in: directory, fileName: "keyameleon.1.log").last?.hasSuffix("Line 10") == true)
    #expect(try logLines(in: directory, fileName: "keyameleon.2.log").last?.hasSuffix("Line 8") == true)
}

@Test("A message with a line break stays one line")
func messageWithLineBreakStaysOneLine() throws {
    let directory = temporaryLogDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let writer = KeyameleonLogWriter.file(directory: directory)

    writer.append(.debug, category: .switching, message: "Connected (Travel\r\nKeyboard)")

    let lines = try logLines(in: directory)
    #expect(lines.count == 1)
    #expect(lines[0].hasSuffix("[debug] [switching] Connected (Travel Keyboard)"))
}

@Test("An oversized record stays inside the file size limit")
func oversizedRecordStaysInsideTheFileSizeLimit() throws {
    let directory = temporaryLogDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let writer = KeyameleonLogWriter.file(
        directory: directory,
        maximumFileByteCount: 120,
        keptRotatedFileCount: 2
    )

    let pastedName = String(repeating: "K", count: 5_000)
    for _ in 1...4 {
        writer.append(.debug, category: .switching, message: "Connected (\(pastedName))")
    }

    let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    #expect(names.isEmpty == false)
    for name in names {
        let byteCount = try Data(contentsOf: directory.appending(path: name)).count
        #expect(byteCount <= 120)
    }

    let lines = try logLines(in: directory)
    #expect(lines.count == 1)
    #expect(lines[0].contains("[debug] [switching] Connected (KKKK"))
    #expect(lines[0].hasSuffix("…"))
}

@Test("Rotation counts bytes another writer appended")
func rotationCountsBytesAnotherWriterAppended() throws {
    let directory = temporaryLogDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let writer = KeyameleonLogWriter.file(
        directory: directory,
        maximumFileByteCount: 200,
        keptRotatedFileCount: 1
    )

    writer.append(.debug, category: .app, message: "First")
    let activeFile = directory.appending(path: KeyameleonLogFile.activeFileName)
    let handle = try FileHandle(forWritingTo: activeFile)
    try handle.seekToEnd()
    try handle.write(contentsOf: Data(repeating: 0x42, count: 200))
    try handle.close()

    writer.append(.debug, category: .app, message: "Second")

    let names = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    #expect(names == ["keyameleon.1.log", "keyameleon.log"])

    let active = try logLines(in: directory)
    #expect(active.count == 1)
    #expect(active[0].hasSuffix("[debug] [app] Second"))

    let rotated = try logLines(in: directory, fileName: "keyameleon.1.log")
    #expect(rotated.first?.hasSuffix("[debug] [app] First") == true)
    #expect(rotated.contains { $0.hasPrefix("BBBB") })
}

@Test("The writer recreates the active file after the user deletes it")
func writerRecreatesActiveFileAfterDeletion() throws {
    let directory = temporaryLogDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let writer = KeyameleonLogWriter.file(directory: directory)
    let activeFile = directory.appending(path: KeyameleonLogFile.activeFileName)

    writer.append(.debug, category: .app, message: "First")
    try FileManager.default.removeItem(at: activeFile)
    writer.append(.debug, category: .app, message: "Second")

    let lines = try logLines(in: directory)
    #expect(lines.count == 1)
    #expect(lines[0].hasSuffix("[debug] [app] Second"))
}

@Test("The writer follows the path when the active file is replaced")
func writerFollowsPathWhenActiveFileIsReplaced() throws {
    let directory = temporaryLogDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let writer = KeyameleonLogWriter.file(directory: directory)
    let activeFile = directory.appending(path: KeyameleonLogFile.activeFileName)

    writer.append(.debug, category: .app, message: "First")
    try FileManager.default.moveItem(at: activeFile, to: directory.appending(path: "moved.log"))
    writer.append(.debug, category: .app, message: "Second")

    let lines = try logLines(in: directory)
    #expect(lines.count == 1)
    #expect(lines[0].hasSuffix("[debug] [app] Second"))
    #expect(
        try logLines(in: directory, fileName: "moved.log").first?
            .hasSuffix("[debug] [app] First") == true
    )
}

@Test("An append-only writer never rotates a full active file")
func appendOnlyWriterNeverRotatesAFullActiveFile() throws {
    let directory = temporaryLogDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let activeFile = directory.appending(path: KeyameleonLogFile.activeFileName)
    try Data(repeating: 0x41, count: KeyameleonLogFile.maximumFileByteCount + 1)
        .write(to: activeFile)

    let writer = KeyameleonLogWriter.appendOnlyFile(directory: directory)
    writer.append(.warning, category: .app, message: "Another instance is running")

    let names = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    #expect(names == [KeyameleonLogFile.activeFileName])
    let contents = try String(contentsOf: activeFile, encoding: .utf8)
    #expect(contents.hasSuffix("[warning] [app] Another instance is running\n"))
}

// The log destination is process-wide, so this test stays on the main actor and
// cannot interleave with another test that installs a writer.
@Test("The process writes nothing until a writer is installed")
@MainActor
func processWritesNothingUntilAWriterIsInstalled() {
    let lines = Mutex<[String]>([])

    KeyameleonLog.debug(.app, "Dropped before start")
    KeyameleonLog.start(KeyameleonLogWriter { level, category, message in
        lines.withLock { $0.append("[\(level.rawValue)] [\(category.rawValue)] \(message)") }
    })
    KeyameleonLog.warning(.setup, "Kept while started")
    KeyameleonLog.stop()
    KeyameleonLog.error(.app, "Dropped after stop")

    let captured = lines.withLock { $0 }
    #expect(captured.contains("[warning] [setup] Kept while started"))
    #expect(captured.contains("[debug] [app] Dropped before start") == false)
    #expect(captured.contains("[error] [app] Dropped after stop") == false)
}

private func temporaryLogDirectory() -> URL {
    FileManager.default.temporaryDirectory.appending(
        path: "KeyameleonLogTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
}

private func logLines(in directory: URL, fileName: String = "keyameleon.log") throws -> [String] {
    let contents = try String(contentsOf: directory.appending(path: fileName), encoding: .utf8)
    return contents.split(separator: "\n").map(String.init)
}

private var currentTimestamp: String {
    Date().formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .current))
}
