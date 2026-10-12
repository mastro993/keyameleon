import Foundation

/// The app that macOS last made active, other than Keyameleon itself.
struct FrontmostApp: Equatable, Sendable {
    let bundleIdentifier: String
    let name: String
}
