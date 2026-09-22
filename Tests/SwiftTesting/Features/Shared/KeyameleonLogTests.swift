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

@Test("The process writes nothing until a writer is installed")
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
