import Testing
@testable import Keyameleon

@Test("Keyameleon shell exposes its stable menu contract")
func keyameleonShellMenuContract() {
    #expect(KeyameleonAppMetadata.bundleIdentifier == "dev.fedemas.keyameleon")
    #expect(KeyameleonAppMetadata.displayName == "Keyameleon")
    #expect(KeyameleonAppMetadata.mainWindowTitle == "Keyameleon")
    #expect(KeyameleonAppMetadata.openMenuItemTitle == "Open Keyameleon…")
    #expect(KeyameleonAppMetadata.quitMenuItemTitle == "Quit Keyameleon")
}
