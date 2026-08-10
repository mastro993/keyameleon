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
    static let continueToAssignmentsButtonTitle = "Continue to Assignments"
    static let finishWithoutAssignmentsButtonTitle = "Finish Without Assignments"
    static let assignButtonTitle = "Assign…"
    static let changeAssignmentButtonTitle = "Change Assignment"
    static let removeAssignmentButtonTitle = "Remove Assignment"
    static let physicalKeyboardNameLabel = "Physical Keyboard Name"
    static let keyboardAssignmentLabel = "Keyboard Assignment"
    static let assignmentAppliesAfterActivation = "Applies after next Activation Activity"
    static let assignmentPickerTitle = "Choose Input Source"
    static let assignmentSearchPrompt = "Search Input Sources"
    static let activePhysicalKeyboardMenuItemPrefix = "Active Physical Keyboard:"
    static let noActivityObservedYet = "No activity observed yet"
    static let activePhysicalKeyboardLabel = "Active Physical Keyboard"
    static let systemSettingsURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
    static let uiTestingResetSetupLaunchArgument = "--reset-guided-setup"

    static func switchingStatusMenuItemTitle(_ status: SwitchingStatus) -> String {
        "\(switchingStatusMenuItemPrefix) \(status.displayName)"
    }

    static func activePhysicalKeyboardMenuItemTitle(_ name: String?) -> String {
        let value = name ?? noActivityObservedYet
        return "\(activePhysicalKeyboardMenuItemPrefix) \(value)"
    }
}
