import Foundation

/// One App Assignment as the Apps pane shows it.
struct AppAssignmentRow: Identifiable, Equatable {
    let assignment: AppAssignment
    /// Nil when the app is not installed. Its App Assignment is kept.
    let appURL: URL?

    var id: String { assignment.bundleIdentifier }
    var isInstalled: Bool { appURL != nil }
}
