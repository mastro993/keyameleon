import Foundation

enum PhysicalKeyboardListOrdering {
    static func sorted(
        _ physicalKeyboards: [PhysicalKeyboard]
    ) -> [PhysicalKeyboard] {
        physicalKeyboards.sorted { left, right in
            let leftRank = sortRank(for: left)
            let rightRank = sortRank(for: right)
            if leftRank != rightRank {
                return leftRank < rightRank
            }

            let nameComparison = left.name.localizedCaseInsensitiveCompare(right.name)
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }

            return left.id.rawValue < right.id.rawValue
        }
    }

    private static func sortRank(
        for physicalKeyboard: PhysicalKeyboard
    ) -> Int {
        if physicalKeyboard.isBuiltIn {
            return 0
        }

        switch physicalKeyboard.connectionState {
        case .connected:
            return 1
        case .disconnected:
            return 2
        }
    }
}
