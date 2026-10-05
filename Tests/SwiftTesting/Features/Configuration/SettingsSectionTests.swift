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
        #expect(!section.systemImage(isSelected: false).isEmpty)
        #expect(!section.systemImage(isSelected: true).isEmpty)
        // The design selects with the filled symbol, so the pair must differ.
        #expect(section.systemImage(isSelected: true) != section.systemImage(isSelected: false))
    }
    #expect(KeyameleonSettingsSection.general.systemImage(isSelected: true) == "gearshape.fill")
    #expect(KeyameleonSettingsSection.keyboards.systemImage(isSelected: true) == "keyboard.fill")
    #expect(KeyameleonSettingsSection.about.systemImage(isSelected: true) == "info.circle.fill")
}

@Test("Settings selection starts on General")
@MainActor
func settingsSelectionStartsOnGeneral() {
    #expect(KeyameleonSettingsSelection().section == .general)
}
