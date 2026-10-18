import Foundation

extension ActivityTriggeredSwitching {
    /// Rereads App Assignments after a saved change. Editing or removing the
    /// Frontmost App's App Assignment ends any Input Source Hold, and a Wanted
    /// Input Source from it follows the edit without selecting anything.
    func handleAppAssignmentChange() {
        guard persistenceError == nil else {
            return
        }
        let frontmostAssignmentChanged: Bool
        do {
            let saved = try appAssignmentStore.allAppAssignments()
            frontmostAssignmentChanged = appAssignments.replaceAssignments(with: saved)
        } catch {
            markPersistenceUnavailable()
            return
        }

        if frontmostAssignmentChanged {
            inputSourceHold.end(reason: "App Assignment changed")
        }
        if let bundleIdentifier = wantedInputSource?.appBundleIdentifier {
            reconcileWantedInputSource(with: appAssignments.assignments[bundleIdentifier]?.inputSourceIdentifier)
        }
        switchingWarnings.reevaluate(appAssignments, eligibleIdentifiers: eligibleIdentifiers)
        rebuildOutcome()
    }
}
