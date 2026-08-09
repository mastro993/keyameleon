enum KeyameleonAppMetadata {
    static let bundleIdentifier = "dev.fedemas.keyameleon"
    static let displayName = "Keyameleon"
    static let mainWindowTitle = "Keyameleon"
    static let menuBarAccessibilityLabel = "Keyameleon"
    static let guidedSetupTitle = "Guided setup"
    static let switchingStatusMenuItemPrefix = "Switching Status:"
    static let openMenuItemTitle = "Open Keyameleon…"
    static let continueSetupMenuItemTitle = "Continue Setup…"
    static let openSystemSettingsMenuItemTitle = "Open System Settings"
    static let checkAgainMenuItemTitle = "Check Again"
    static let quitMenuItemTitle = "Quit Keyameleon"
    static let requestPermissionButtonTitle = "Request Permission"
    static let continueWithoutPermissionButtonTitle = "Continue Without Permission"
    static let finishSetupButtonTitle = "Finish Setup"
    static let systemSettingsURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
    static let uiTestingResetSetupLaunchArgument = "--reset-guided-setup"

    static func switchingStatusMenuItemTitle(_ status: SwitchingStatus) -> String {
        "\(switchingStatusMenuItemPrefix) \(status.displayName)"
    }
}
