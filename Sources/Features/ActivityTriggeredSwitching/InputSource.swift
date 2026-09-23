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
    /// Languages the layout serves, most specific first. Empty when unknown.
    let languages: [String]

    init(
        identifier: String,
        name: String,
        category: InputSourceCategory,
        type: InputSourceType,
        isEnabled: Bool,
        isSelectCapable: Bool,
        languages: [String] = []
    ) {
        self.identifier = identifier
        self.name = name
        self.category = category
        self.type = type
        self.isEnabled = isEnabled
        self.isSelectCapable = isSelectCapable
        self.languages = languages
    }
}

struct EligibleInputSource: Identifiable, Equatable, Sendable {
    let identifier: String
    let name: String
    /// ISO 639 code of the layout's primary language, such as `IT` or `EN`.
    /// `nil` when the system reports no language for the layout.
    let languageCode: String?

    init(identifier: String, name: String, languageCode: String? = nil) {
        self.identifier = identifier
        self.name = name
        self.languageCode = languageCode
    }

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
            .map {
                EligibleInputSource(
                    identifier: $0.identifier,
                    name: $0.name,
                    languageCode: languageCode(from: $0.languages)
                )
            }
            .sorted { left, right in
                let nameComparison = left.name.localizedCaseInsensitiveCompare(right.name)
                if nameComparison != .orderedSame {
                    return nameComparison == .orderedAscending
                }

                return left.identifier < right.identifier
            }
    }

    /// Primary language of the layout as an uppercase ISO 639 code.
    ///
    /// macOS reports script and region variants such as `hi_Latn`; only the
    /// language subtag reaches the panel.
    static func languageCode(from languages: [String]) -> String? {
        guard let primary = languages.first else {
            return nil
        }

        let code = primary.prefix { $0 != "-" && $0 != "_" }
        guard (2...3).contains(code.count) else {
            return nil
        }

        return code.uppercased()
    }
}
