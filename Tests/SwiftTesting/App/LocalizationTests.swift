import Foundation
import Testing
@testable import Keyameleon

/// The website's languages, besides English.
private let translatedLanguages = ["ar", "es", "fr", "it", "ja", "ko", "zh-Hans", "zh-Hant"]

@Test("The app ships every website language", arguments: translatedLanguages)
func appShipsLanguage(_ language: String) {
    #expect(Bundle.main.localizations.contains(language))

    var resource = LocalizedStringResource.openSystemSettings
    resource.locale = Locale(identifier: language)
    #expect(String(localized: resource) != "Open System Settings")
}

@Test("Plural strings follow the language's plural rules")
func pluralStringsFollowLanguageRules() {
    var resource = LocalizedStringResource.readyKeyboardsAssigned(2)
    #expect(String(localized: resource) == "2 keyboards assigned")
    resource.locale = Locale(identifier: "it")
    #expect(String(localized: resource) == "2 tastiere assegnate")
}
