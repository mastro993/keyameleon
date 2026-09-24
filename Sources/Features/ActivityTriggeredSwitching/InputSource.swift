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
    /// Locale code of the layout, such as `US` or `IT`. `nil` when the system
    /// reports no language for the layout.
    let localeCode: String?

    init(identifier: String, name: String, localeCode: String? = nil) {
        self.identifier = identifier
        self.name = name
        self.localeCode = localeCode
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
                    localeCode: localeCode(from: $0.languages)
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

    /// Locale code of the layout, such as `US` for a U.S. layout or `IT` for an
    /// Italian one.
    ///
    /// macOS reports the layout's language alone, so the region comes from that
    /// language's canonical locale. A language without a canonical region falls
    /// back to its ISO 639 code.
    static func localeCode(from languages: [String]) -> String? {
        guard let primary = languages.first else {
            return nil
        }

        return regionCode(from: primary) ?? languageCode(from: primary)
    }

    /// Region of the language's canonical locale, such as `US` for `en`.
    private static func regionCode(from language: String) -> String? {
        let maximal = Locale(identifier: language).language.maximalIdentifier
        guard
            let region = maximal.split(separator: "-").last,
            region.count == 2,
            region.allSatisfy(\.isUppercase)
        else {
            return nil
        }

        return String(region)
    }

    /// Primary language of the layout as an uppercase ISO 639 code.
    ///
    /// macOS reports script and region variants such as `hi_Latn`; only the
    /// language subtag reaches the fallback.
    private static func languageCode(from language: String) -> String? {
        let code = language.prefix { $0 != "-" && $0 != "_" }
        guard (2...3).contains(code.count) else {
            return nil
        }

        return code.uppercased()
    }
}
