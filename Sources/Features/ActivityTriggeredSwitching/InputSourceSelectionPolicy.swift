import Foundation

/// Branch choice for selecting an Input Source and verifying the exact readback.
///
/// The provider performs the Carbon effects; this policy owns every decision,
/// so the restore branch is locked without touching the machine's Input Source.
enum InputSourceSelectionPolicy {
    enum Prepare: Equatable {
        case reject
        case alreadyCurrent
        case select(normalized: String, previous: String?)
    }

    enum AfterSelect: Equatable {
        case verified
        case restore(previousIdentifier: String)
        case failed
    }

    static func prepare(identifier: String, current: String?) -> Prepare {
        let normalized = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return .reject }
        if current == normalized { return .alreadyCurrent }
        return .select(normalized: normalized, previous: current)
    }

    static func afterSelect(
        selectSucceeded: Bool,
        currentAfter: String?,
        normalized: String,
        previous: String?
    ) -> AfterSelect {
        guard selectSucceeded else { return .failed }
        if currentAfter == normalized { return .verified }
        if let previous { return .restore(previousIdentifier: previous) }
        return .failed
    }
}
