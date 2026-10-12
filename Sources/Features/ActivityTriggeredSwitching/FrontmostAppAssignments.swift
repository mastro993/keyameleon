import Foundation

/// The Frontmost App and the saved App Assignments, as Activity-Triggered
/// Switching sees them. Saved assignments are read once per change, so
/// selection never reads the store per key press.
struct FrontmostAppAssignments: Equatable {
    /// Keyameleon's own activations are not App Activations.
    let ownBundleIdentifier: String?
    private(set) var frontmostApp: FrontmostApp?
    private(set) var assignments: [String: AppAssignment] = [:]

    var frontmostAssignment: AppAssignment? {
        frontmostApp.flatMap { assignments[$0.bundleIdentifier] }
    }

    /// Records an app macOS made active. Returns whether it is an App
    /// Activation: Keyameleon itself and the app already frontmost are not.
    mutating func noteActivation(of app: FrontmostApp) -> Bool {
        guard app.bundleIdentifier != ownBundleIdentifier,
              app.bundleIdentifier != frontmostApp?.bundleIdentifier else {
            return false
        }
        frontmostApp = app
        return true
    }

    /// Replaces the saved App Assignments. Returns whether the Frontmost App's
    /// App Assignment changed.
    mutating func replaceAssignments(with saved: [AppAssignment]) -> Bool {
        let previous = frontmostAssignment
        assignments = Dictionary(saved.map { ($0.bundleIdentifier, $0) }) { _, latest in latest }
        return previous != frontmostAssignment
    }

    /// The Frontmost App's App Assignment for the outcome, with its Input
    /// Source when available.
    func outcome(eligibleInputSources: [EligibleInputSource]) -> ActivityTriggeredSwitchingAppAssignment? {
        guard let frontmostApp, let assignment = frontmostAssignment else { return nil }
        return ActivityTriggeredSwitchingAppAssignment(
            bundleIdentifier: frontmostApp.bundleIdentifier,
            appName: frontmostApp.name,
            inputSource: eligibleInputSources.first { $0.identifier == assignment.inputSourceIdentifier }
        )
    }
}
