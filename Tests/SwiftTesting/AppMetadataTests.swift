import Testing
@testable import Keyameleon

@Test("Keyameleon shell exposes its stable menu contract")
func keyameleonShellMenuContract() {
    #expect(KeyameleonAppMetadata.bundleIdentifier == "dev.fedemas.keyameleon")
    #expect(KeyameleonAppMetadata.displayName == "Keyameleon")
    #expect(KeyameleonAppMetadata.mainWindowTitle == "Keyameleon")
    #expect(KeyameleonAppMetadata.guidedSetupTitle == "Guided setup")
    #expect(KeyameleonAppMetadata.openMenuItemTitle == "Open Keyameleon…")
    #expect(KeyameleonAppMetadata.continueSetupMenuItemTitle == "Continue Setup…")
    #expect(KeyameleonAppMetadata.openSystemSettingsMenuItemTitle == "Open System Settings")
    #expect(KeyameleonAppMetadata.checkAgainMenuItemTitle == "Check Again")
    #expect(KeyameleonAppMetadata.quitMenuItemTitle == "Quit Keyameleon")
    #expect(KeyameleonAppMetadata.settingsMenuItemTitle == "Settings…")
    #expect(KeyameleonAppMetadata.checkForUpdatesMenuItemTitle == "Check for Updates…")
    #expect(KeyameleonAppMetadata.generalSettingsTitle == "General")
    #expect(KeyameleonAppMetadata.launchAtLoginToggleTitle == "Launch at Login")
    #expect(KeyameleonAppMetadata.noActivityObservedYet == "No activity observed yet")
    #expect(
        KeyameleonAppMetadata.pauseActivityTriggeredSwitchingMenuItemTitle
            == "Pause Activity-Triggered Switching"
    )
    #expect(
        KeyameleonAppMetadata.resumeActivityTriggeredSwitchingMenuItemTitle
            == "Resume Activity-Triggered Switching"
    )
    #expect(KeyameleonAppMetadata.keyboardAssignmentMenuItemPrefix == "Keyboard Assignment:")
    #expect(KeyameleonAppMetadata.currentInputSourceMenuItemPrefix == "Current Input Source:")
}
