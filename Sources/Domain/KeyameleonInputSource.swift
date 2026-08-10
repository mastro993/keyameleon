import Foundation

enum InputSourceCategory: Equatable, Sendable {
    case keyboard
    case palette
    case ink
    case other
}

enum InputSourceType: Equatable, Sendable {
    case keyboardLayout
    case keyboardInputMethodWithoutModes
    case keyboardInputMethodWithModes
    case keyboardInputMode
    case other
}

struct InputSourceFacts: Equatable, Sendable {
    let identifier: String
    let name: String
    let category: InputSourceCategory
    let type: InputSourceType
    let isEnabled: Bool
    let isSelectCapable: Bool
}

struct EligibleInputSource: Identifiable, Equatable, Sendable {
    let identifier: String
    let name: String

    var id: String {
        identifier
    }
}

enum EligibleInputSourceCatalog {
    static func eligible(from facts: [InputSourceFacts]) -> [EligibleInputSource] {
        var seenIdentifiers = Set<String>()

        return facts
            .filter { fact in
                fact.category == .keyboard
                    && fact.type == .keyboardLayout
                    && fact.isEnabled
                    && fact.isSelectCapable
                    && !fact.identifier.isEmpty
                    && !fact.name.isEmpty
            }
            .filter { seenIdentifiers.insert($0.identifier).inserted }
            .map { EligibleInputSource(identifier: $0.identifier, name: $0.name) }
            .sorted { left, right in
                let nameComparison = left.name.localizedCaseInsensitiveCompare(right.name)
                if nameComparison != .orderedSame {
                    return nameComparison == .orderedAscending
                }

                return left.identifier < right.identifier
            }
    }
}
