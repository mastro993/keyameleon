import Foundation

/// The active switching warnings, one per cause. Repeated Physical Keyboard
/// Events and App Activations of one cause share its warning.
struct SwitchingWarnings: Equatable {
    private(set) var byCause: [SwitchingWarning.Cause: SwitchingWarning] = [:]
    /// Counts warnings opened while no warning of their cause was active.
    private(set) var episodeCount = 0

    var sorted: [SwitchingWarning] {
        byCause.values.sorted { $0.id < $1.id }
    }

    mutating func open(_ warning: SwitchingWarning) {
        if byCause[warning.cause] == nil {
            episodeCount += 1
        }
        byCause[warning.cause] = warning
    }

    mutating func clear(_ cause: SwitchingWarning.Cause) {
        byCause.removeValue(forKey: cause)
    }

    /// Opens a warning for each saved Keyboard Assignment whose Input Source is
    /// not available and clears the rest. An excluded device keeps its record,
    /// so its warning must not survive. Returns whether a keyboard warning changed.
    @discardableResult
    mutating func reevaluateKeyboardAssignments(
        _ records: [SavedPhysicalKeyboardRecord],
        eligibleIdentifiers: Set<String>,
        excludedKeys: Set<String>
    ) -> Bool {
        var changed = false
        var remainingUnavailableIDs = Set(byCause.keys.compactMap { cause -> PhysicalKeyboardRecordID? in
            guard case let .unavailableKeyboardAssignment(id) = cause else { return nil }
            return id
        })

        for record in records {
            guard let assignment = record.keyboardAssignment,
                  !excludedKeys.contains(PhysicalKeyboardExclusionKey.key(for: record.recordID)) else {
                continue
            }

            let cause = SwitchingWarning.Cause.unavailableKeyboardAssignment(record.recordID)
            if eligibleIdentifiers.contains(assignment.inputSourceIdentifier) {
                if byCause[cause] != nil {
                    clear(cause)
                    changed = true
                }
            } else {
                let previous = byCause[cause]
                open(.unavailableKeyboardAssignment(
                    physicalKeyboardID: record.recordID,
                    inputSourceIdentifier: assignment.inputSourceIdentifier
                ))
                if previous?.inputSourceIdentifier != assignment.inputSourceIdentifier {
                    changed = true
                }
            }
            remainingUnavailableIDs.remove(record.recordID)
        }

        for staleID in remainingUnavailableIDs {
            clear(.unavailableKeyboardAssignment(staleID))
            changed = true
        }
        return changed
    }

    /// Opens a warning for each App Assignment whose Input Source is not
    /// available and clears the rest. Nothing is selected in its place.
    mutating func reevaluate(_ appAssignments: FrontmostAppAssignments, eligibleIdentifiers: Set<String>) {
        let unavailable = appAssignments.assignments.values.filter {
            !eligibleIdentifiers.contains($0.inputSourceIdentifier)
        }
        let unavailableIDs = Set(unavailable.map(\.bundleIdentifier))
        for case let .unavailableAppAssignment(bundleIdentifier) in byCause.keys
            where !unavailableIDs.contains(bundleIdentifier) {
            clear(.unavailableAppAssignment(bundleIdentifier))
        }
        for assignment in unavailable {
            open(.unavailableAppAssignment(
                bundleIdentifier: assignment.bundleIdentifier,
                inputSourceIdentifier: assignment.inputSourceIdentifier
            ))
        }
    }
}
