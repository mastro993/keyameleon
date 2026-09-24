import Foundation

@MainActor
protocol PhysicalKeyboardExclusionStoring: AnyObject {
    func allExclusions() -> [SavedPhysicalKeyboardExclusion]
    func exclude(_ exclusion: SavedPhysicalKeyboardExclusion)
    func restore(key: String)
}

@MainActor
final class InMemoryPhysicalKeyboardExclusionStore: PhysicalKeyboardExclusionStoring {
    private var exclusions: [SavedPhysicalKeyboardExclusion] = []

    func allExclusions() -> [SavedPhysicalKeyboardExclusion] {
        exclusions
    }

    func exclude(_ exclusion: SavedPhysicalKeyboardExclusion) {
        exclusions.removeAll { $0.key == exclusion.key }
        exclusions.append(exclusion)
    }

    func restore(key: String) {
        exclusions.removeAll { $0.key == key }
    }
}

@MainActor
final class UserDefaultsPhysicalKeyboardExclusionStore: PhysicalKeyboardExclusionStoring {
    private enum Key {
        static let exclusions = "keyameleon.excludedPhysicalKeyboards"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// A stored set that fails to decode reads as no exclusion, so a damaged
    /// preference hides no device instead of keeping one hidden silently.
    func allExclusions() -> [SavedPhysicalKeyboardExclusion] {
        guard let data = defaults.data(forKey: Key.exclusions) else {
            return []
        }

        return (try? JSONDecoder().decode([SavedPhysicalKeyboardExclusion].self, from: data)) ?? []
    }

    func exclude(_ exclusion: SavedPhysicalKeyboardExclusion) {
        var exclusions = allExclusions()
        exclusions.removeAll { $0.key == exclusion.key }
        exclusions.append(exclusion)
        save(exclusions)
    }

    func restore(key: String) {
        save(allExclusions().filter { $0.key != key })
    }

    private func save(_ exclusions: [SavedPhysicalKeyboardExclusion]) {
        guard let data = try? JSONEncoder().encode(exclusions) else {
            return
        }

        defaults.set(data, forKey: Key.exclusions)
    }
}
