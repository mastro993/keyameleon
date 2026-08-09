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
}
