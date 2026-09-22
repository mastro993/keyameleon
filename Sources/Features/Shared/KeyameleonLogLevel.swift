/// Severity of one log line. `verbose` carries the most detail.
enum KeyameleonLogLevel: String, Equatable, Sendable, CaseIterable {
    case verbose
    case debug
    case warning
    case error
}
