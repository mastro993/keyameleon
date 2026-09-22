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
        let line = Self.line(
            level: level,
            category: category,
            message: message,
            maximumByteCount: maximumFileByteCount
        )
        let lineByteCount = line.utf8.count

        // Every file operation is best effort. A missing folder, a full disk, or
        // a locked file must never interrupt switching.
        state.withLock { state in
            guard let descriptor = openIfNeeded(&state) else {
                return
            }
            // The descriptor's own size, because a blocked launch appends through
            // its own writer and a cached count would miss those bytes.
            if rotates, Self.fileByteCount(descriptor) + lineByteCount > maximumFileByteCount {
                close(&state)
                rotate()
                guard openIfNeeded(&state) != nil else {
                    return
                }
            }
            guard
                let rotatedDescriptor = state.descriptor,
                Self.write(line, to: rotatedDescriptor) != nil
            else {
                close(&state)
                return
            }
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
        return descriptor
    }

    private func close(_ state: inout State) {
        guard let descriptor = state.descriptor else {
            return
        }
        Darwin.close(descriptor)
        state.descriptor = nil
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
        message: String,
        maximumByteCount: Int
    ) -> String {
        let timestamp = Date().formatted(
            Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .current)
        )
        let prefix = "\(timestamp) [\(level.rawValue)] [\(category.rawValue)] "
        return prefix + boundedMessage(
            singleLineMessage(message),
            toUTF8ByteCount: maximumByteCount - prefix.utf8.count - 1
        ) + "\n"
    }

    /// A Physical Keyboard Name comes from hardware or from a paste, so one
    /// message can be larger than the whole file budget. Rotation happens before
    /// the write, so an unbounded record would land in a fresh file and overrun
    /// the size limit on its own.
    private static func boundedMessage(_ message: String, toUTF8ByteCount limit: Int) -> String {
        guard message.utf8.count > limit else {
            return message
        }
        let marker = "…"
        let marksTruncation = limit >= marker.utf8.count
        let textLimit = marksTruncation ? limit - marker.utf8.count : limit
        var used = 0
        var end = message.startIndex
        for index in message.indices {
            let width = message[index].utf8.count
            guard used + width <= textLimit else {
                break
            }
            used += width
            end = message.index(after: index)
        }
        let text = String(message[message.startIndex..<end])
        return marksTruncation ? text + marker : text
    }

    /// A Physical Keyboard Name comes from hardware or from the user, so it can
    /// contain a line break that would split one record into two.
    private static func singleLineMessage(_ message: String) -> String {
        guard message.contains(where: \.isNewline) else {
            return message
        }
        return message.split(whereSeparator: \.isNewline).joined(separator: " ")
    }

    private static func fileByteCount(_ descriptor: Int32) -> Int {
        var information = stat()
        guard fstat(descriptor, &information) == 0 else {
            return 0
        }
        return Int(information.st_size)
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
