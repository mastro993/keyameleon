import Testing
@testable import Keyameleon

@Test("Settings sections are General, Keyboards, then About")
func settingsSectionsAreGeneralKeyboardsThenAbout() {
    #expect(KeyameleonSettingsSection.allCases == [.general, .keyboards, .about])
    #expect(KeyameleonSettingsSection.general.title == "General")
    #expect(KeyameleonSettingsSection.keyboards.title == "Keyboards")
    #expect(KeyameleonSettingsSection.about.title == "About")
    for section in KeyameleonSettingsSection.allCases {
        #expect(!section.title.isEmpty)
        #expect(!section.subtitle.isEmpty)
        #expect(!section.systemImage.isEmpty)
    }
}

@Test("Settings selection starts on General")
@MainActor
func settingsSelectionStartsOnGeneral() {
    #expect(KeyameleonSettingsSelection().section == .general)
}

@Test("App identity falls back when bundle keys are missing")
func appIdentityFallsBackWhenBundleKeysAreMissing() {
    let identity = KeyameleonAppIdentity(infoDictionary: [:])
    #expect(identity.name == "Keyameleon")
    #expect(identity.version == "—")
}

@Test("App identity trims empty bundle strings as absent")
func appIdentityTrimsEmptyBundleStringsAsAbsent() {
    let identity = KeyameleonAppIdentity(
        infoDictionary: [
            "CFBundleDisplayName": "  ",
            "CFBundleName": "Fallback",
            "CFBundleShortVersionString": "\n",
        ]
    )
    #expect(identity.name == "Fallback")
    #expect(identity.version == "—")
}

@Test("App identity prefers display name and short version")
func appIdentityPrefersDisplayNameAndShortVersion() {
    let identity = KeyameleonAppIdentity(
        infoDictionary: [
            "CFBundleDisplayName": "Shown",
            "CFBundleName": "Hidden",
            "CFBundleShortVersionString": "1.2.3",
        ]
    )
    #expect(identity.name == "Shown")
    #expect(identity.version == "1.2.3")
}
