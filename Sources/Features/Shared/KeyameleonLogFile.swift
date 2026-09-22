import Foundation
import Synchronization

/// One active text file with numbered size rotation.
///
/// Each append is a single `write(2)` of one complete line against a descriptor
/// opened `O_APPEND`, so a crash can truncate only the line in flight and
/// concurrent emitters cannot interleave partial lines.
final class KeyameleonLogFile: Sendable {
    static let activeFileName = "keyameleon.log"
    static let maximumFileByteCount = 1 << 20
    static let keptRotatedFileCount = 5

    private struct State {
        var descriptor: Int32?
        var byteCount = 0
    }

    private let directory: URL
    private let maximumFileByteCount: Int
    private let keptRotatedFileCount: Int
    private let rotates: Bool
    private let state = Mutex(State())

    init(
        directory: URL,
        maximumFileByteCount: Int = KeyameleonLogFile.maximumFileByteCount,
        keptRotatedFileCount: Int = KeyameleonLogFile.keptRotatedFileCount,
        rotates: Bool = true
    ) {
        self.directory = directory
        self.maximumFileByteCount = maximumFileByteCount
        self.keptRotatedFileCount = keptRotatedFileCount
        self.rotates = rotates
    }

    func append(_ level: KeyameleonLogLevel, category: KeyameleonLogCategory, message: String) {
        let line = Self.line(level: level, category: category, message: message)
        let lineByteCount = line.utf8.count

        // Every file operation is best effort. A missing folder, a full disk, or
        // a locked file must never interrupt switching.
        state.withLock { state in
            guard openIfNeeded(&state) != nil else {
                return
            }
            if rotates, state.byteCount + lineByteCount > maximumFileByteCount, state.byteCount > 0 {
                close(&state)
                rotate()
                guard openIfNeeded(&state) != nil else {
                    return
                }
            }
            guard
                let descriptor = state.descriptor,
                let written = Self.write(line, to: descriptor)
            else {
                close(&state)
                return
            }
            state.byteCount += written
        }
    }

    deinit {
        state.withLock { close(&$0) }
    }

    private func openIfNeeded(_ state: inout State) -> Int32? {
        if let descriptor = state.descriptor {
            return descriptor
        }
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let descriptor = Darwin.open(
            activeFileURL.path,
            O_WRONLY | O_CREAT | O_APPEND,
            0o644
        )
        guard descriptor >= 0 else {
            return nil
        }
        state.descriptor = descriptor
        state.byteCount = Self.fileByteCount(at: activeFileURL)
        return descriptor
    }

    private func close(_ state: inout State) {
        guard let descriptor = state.descriptor else {
            return
        }
        Darwin.close(descriptor)
        state.descriptor = nil
        state.byteCount = 0
    }

    private func rotate() {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: rotatedFileURL(index: keptRotatedFileCount))
        for index in stride(from: keptRotatedFileCount - 1, through: 1, by: -1) {
            try? fileManager.moveItem(
                at: rotatedFileURL(index: index),
                to: rotatedFileURL(index: index + 1)
            )
        }
        try? fileManager.moveItem(at: activeFileURL, to: rotatedFileURL(index: 1))
    }

    private var activeFileURL: URL {
        directory.appending(path: Self.activeFileName)
    }

    private func rotatedFileURL(index: Int) -> URL {
        directory.appending(path: "keyameleon.\(index).log")
    }

    private static func line(
        level: KeyameleonLogLevel,
        category: KeyameleonLogCategory,
        message: String
    ) -> String {
        let timestamp = Date().formatted(
            Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .current)
        )
        return "\(timestamp) [\(level.rawValue)] [\(category.rawValue)] \(message)\n"
    }

    private static func fileByteCount(at url: URL) -> Int {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.size] as? Int ?? 0
    }

    private static func write(_ line: String, to descriptor: Int32) -> Int? {
        var bytes = Array(line.utf8)
        let total = bytes.count
        let written = bytes.withUnsafeMutableBufferPointer { buffer -> Int in
            var offset = 0
            while offset < total {
                let count = Darwin.write(descriptor, buffer.baseAddress! + offset, total - offset)
                guard count > 0 else {
                    return offset
                }
                offset += count
            }
            return offset
        }
        guard written == total else {
            return nil
        }
        return written
    }
}
