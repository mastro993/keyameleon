import Foundation

/// An app the person can give an App Assignment.
struct InstalledApp: Identifiable, Equatable, Sendable {
    let bundleIdentifier: String
    let name: String
    let url: URL

    var id: String { bundleIdentifier }
}
