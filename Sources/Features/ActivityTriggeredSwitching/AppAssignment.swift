import Foundation

/// The saved relation between one app and its wanted Input Source.
///
/// While its app is the Frontmost App, an App Assignment overrides the
/// Keyboard Assignment of every Physical Keyboard.
struct AppAssignment: Identifiable, Equatable, Hashable, Sendable {
    /// Recognizes the app across updates and moves.
    let bundleIdentifier: String
    /// The app's name when it was assigned, shown while the app is not installed.
    let appName: String
    let inputSourceIdentifier: String

    var id: String { bundleIdentifier }
}
