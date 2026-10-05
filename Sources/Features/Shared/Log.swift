import Synchronization

/// The process-wide log. A call site emits one line and never carries a writer.
enum Log {
    private static let writer = Mutex<LogWriter>(.inactive)

    static func start(_ writer: LogWriter) {
        Self.writer.withLock { $0 = writer }
    }

    static func stop() {
        Self.writer.withLock { $0 = .inactive }
    }

    static func verbose(_ category: LogCategory, _ message: String) {
        append(.verbose, category, message)
    }

    static func debug(_ category: LogCategory, _ message: String) {
        append(.debug, category, message)
    }

    static func warning(_ category: LogCategory, _ message: String) {
        append(.warning, category, message)
    }

    static func error(_ category: LogCategory, _ message: String) {
        append(.error, category, message)
    }

    private static func append(
        _ level: LogLevel,
        _ category: LogCategory,
        _ message: String
    ) {
        let destination = writer.withLock { $0 }
        destination.append(level, category: category, message: message)
    }
}
