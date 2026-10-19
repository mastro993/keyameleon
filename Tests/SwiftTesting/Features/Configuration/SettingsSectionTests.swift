import Foundation
import Testing
@testable import Keyameleon

@Test("Settings sections are General, Keyboards, Apps, then About")
func settingsSectionsAreGeneralKeyboardsAppsThenAbout() {
    #expect(SettingsSection.allCases == [.general, .keyboards, .apps, .about])
    #expect(String(localized: SettingsSection.general.title) == "General")
    #expect(String(localized: SettingsSection.keyboards.title) == "Keyboards")
    #expect(String(localized: SettingsSection.apps.title) == "Apps")
    #expect(String(localized: SettingsSection.about.title) == "About")
    #expect(SettingsSection.allCases.map(\.systemImage) == ["gearshape", "keyboard", "square.grid.2x2", "info.circle"])
}

@Test("Settings selection starts on General")
@MainActor
func settingsSelectionStartsOnGeneral() {
    #expect(SettingsSelection().section == .general)
}
