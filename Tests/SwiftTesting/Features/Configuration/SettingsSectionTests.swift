import Testing
@testable import Keyameleon

@Test("Settings sections are General, Keyboards, then About")
func settingsSectionsAreGeneralKeyboardsThenAbout() {
    #expect(SettingsSection.allCases == [.general, .keyboards, .about])
    #expect(SettingsSection.general.title == "General")
    #expect(SettingsSection.keyboards.title == "Keyboards")
    #expect(SettingsSection.about.title == "About")
    for section in SettingsSection.allCases {
        #expect(!section.title.isEmpty)
        #expect(!section.systemImage(isSelected: false).isEmpty)
        #expect(!section.systemImage(isSelected: true).isEmpty)
        // The design selects with the filled symbol, so the pair must differ.
        #expect(section.systemImage(isSelected: true) != section.systemImage(isSelected: false))
    }
    #expect(SettingsSection.general.systemImage(isSelected: true) == "gearshape.fill")
    #expect(SettingsSection.keyboards.systemImage(isSelected: true) == "keyboard.fill")
    #expect(SettingsSection.about.systemImage(isSelected: true) == "info.circle.fill")
}

@Test("Settings selection starts on General")
@MainActor
func settingsSelectionStartsOnGeneral() {
    #expect(SettingsSelection().section == .general)
}
