import Synchronization

/// The process-wide log. A call site emits one line and never carries a writer.
enum KeyameleonLog {
    private static let writer = Mutex<KeyameleonLogWriter>(.inactive)

    static func start(_ writer: KeyameleonLogWriter) {
        Self.writer.withLock { $0 = writer }
    }

    static func stop() {
        Self.writer.withLock { $0 = .inactive }
    }

    static func verbose(_ category: KeyameleonLogCategory, _ message: String) {
        append(.verbose, category, message)
    }

    static func debug(_ category: KeyameleonLogCategory, _ message: String) {
        append(.debug, category, message)
    }

    static func warning(_ category: KeyameleonLogCategory, _ message: String) {
        append(.warning, category, message)
    }

    static func error(_ category: KeyameleonLogCategory, _ message: String) {
        append(.error, category, message)
    }

    private static func append(
        _ level: KeyameleonLogLevel,
        _ category: KeyameleonLogCategory,
        _ message: String
    ) {
        let destination = writer.withLock { $0 }
        destination.append(level, category: category, message: message)
    }
}
