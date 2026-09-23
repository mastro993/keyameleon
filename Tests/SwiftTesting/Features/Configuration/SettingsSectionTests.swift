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
        #expect(!section.systemImage.isEmpty)
    }
}

@Test("Settings selection starts on General")
@MainActor
func settingsSelectionStartsOnGeneral() {
    #expect(KeyameleonSettingsSelection().section == .general)
}
