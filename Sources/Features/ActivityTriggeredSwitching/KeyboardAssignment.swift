import Foundation

struct KeyboardAssignment: Equatable, Sendable {
    let inputSourceIdentifier: String

    init?(inputSourceIdentifier: String) {
        let normalized = inputSourceIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return nil
        }

        self.inputSourceIdentifier = normalized
    }
}
