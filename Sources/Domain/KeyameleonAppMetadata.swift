enum KeyameleonAppMetadata {
    static let bundleIdentifier = "dev.fedemas.keyameleon"
    static let displayName = "Keyameleon"
    static let mainWindowTitle = "Keyameleon"
    static let menuBarAccessibilityLabel = "Keyameleon"
    static let guidedSetupTitle = "Guided setup"
    static let switchingStatusMenuItemPrefix = "Switching Status:"
    static let switchingStatusReasonMenuItemPrefix = "Detected reason:"
    static let temporarilyUnavailableAutomaticRecovery =
        "Resumes automatically when macOS allows Activity-Triggered Switching."
    static let activePhysicalKeyboardMenuItemPrefix = "Active Physical Keyboard:"
    static let keyboardAssignmentMenuItemPrefix = "Keyboard Assignment:"
    static let currentInputSourceMenuItemPrefix = "Current Input Source:"
    static let needsActionMenuItemPrefix = "Needs action:"
    static let noActivityObservedYet = "No activity observed yet"
    static let menuValueUnavailable = "—"
    static let pauseActivityTriggeredSwitchingMenuItemTitle = "Pause Activity-Triggered Switching"
    static let resumeActivityTriggeredSwitchingMenuItemTitle = "Resume Activity-Triggered Switching"
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
    static let replaceSavedPhysicalKeyboardButtonTitle = "Replace Saved Physical Keyboard…"
    static let forgetPhysicalKeyboardButtonTitle = "Forget Physical Keyboard…"
    static let forgetConfirmationTitle = "Forget Physical Keyboard?"
    static let replaceConfirmationTitle = "Replace Saved Physical Keyboard?"
    static let confirmForgetButtonTitle = "Forget"
    static let confirmReplaceButtonTitle = "Replace"
    static let activePhysicalKeyboardLabel = "Active"
    static let physicalKeyboardNameLabel = "Physical Keyboard Name"
    static let keyboardAssignmentLabel = "Keyboard Assignment"
    static let assignmentAppliesAfterActivation = "Applies after next Activation Activity"
    static let currentInputSourceLabel = "Current Input Source"
    static let assignedInputSourceLabel = "Assigned Input Source"
    static let inputSourceRestoresAfterActivation =
        "Later Activation Activity restores the Keyboard Assignment."
    static let assignmentPickerTitle = "Choose Input Source"
    static let assignmentSearchPrompt = "Search Input Sources"
    static let replaceSavedPhysicalKeyboardPickerTitle = "Replace Saved Physical Keyboard"
    static let systemSettingsURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
    static let notificationSettingsURL = "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
    static let uiTestingResetSetupLaunchArgument = "--reset-guided-setup"
    static let guidedSetupAccessibilityIdentifier = "guided-setup"
    static let switchingStatusAccessibilityIdentifier = "switching-status"
    static let activePhysicalKeyboardAccessibilityIdentifier = "active-physical-keyboard"
    static let physicalKeyboardConfigurationAccessibilityIdentifier = "physical-keyboard-configuration"
    static let operationalNotificationSetupAccessibilityIdentifier = "operational-notification-setup"
    static let diagnosticBundleReviewAccessibilityIdentifier = "diagnostic-bundle-review"
    static let requestPermissionAccessibilityIdentifier = "request-permission"
    static let continueToAssignmentsAccessibilityIdentifier = "continue-to-assignments"
    static let finishWithoutAssignmentsAccessibilityIdentifier = "finish-without-assignments"
    static let settingsMenuItemTitle = "Settings…"
    static let checkForUpdatesMenuItemTitle = "Check for Updates…"
    static let generalSettingsTitle = "General"
    static let launchAtLoginToggleTitle = "Launch at Login"
    static let launchAtLoginFooter =
        "Starts Keyameleon when you log in. Uses Service Management for the main app only."
    static let launchAtLoginErrorMessage =
        "Could not change Launch at Login. Open System Settings → General → Login Items if macOS requires approval."
    static let updatesSettingsSectionTitle = "Updates"
    static let checkForUpdatesButtonTitle = "Check for Updates…"
    static let updateApprovalExplanation =
        "Keyameleon checks for updates at most once every 24 hours on launch. You approve every installation."
    static let criticalUpdateWarningExplanation =
        "A critical update shows a clear warning. Keyameleon still waits for your approval and never forces an update."
    static let operationalNotificationTitle = "Keyameleon needs attention"
    static let operationalNotificationSetupTitle = "Optional operational notifications"
    static let operationalNotificationSetupExplanation =
        "Keyameleon can alert you only when listen permission is revoked or a Keyboard Assignment becomes unavailable. It requests alert access only. It does not request sound or icon badge access."
    static let enableOperationalNotificationsButtonTitle = "Enable Operational Notifications"
    static let skipOperationalNotificationsButtonTitle = "Not Now"
    static let notificationAuthorizationLabel = "Notification Authorization"
    static let notificationAuthorizationFooter =
        "Operational notifications are optional. They never block Activity-Triggered Switching. Keyameleon requests alert access only; it does not request sound or icon badge access."
    static let openNotificationSettingsButtonTitle = "Open System Settings…"
    static let listenPermissionRevokedNotificationBody =
        "Input Monitoring permission was revoked. Open System Settings to restore Activity-Triggered Switching."
    static let unavailableKeyboardAssignmentNotificationBody =
        "A Keyboard Assignment is unavailable. Open Keyameleon to change or remove it."
    static let retryNowButtonTitle = "Retry Now"
    static let switchingWarningsSectionTitle = "Warnings"
    static let selectionFailedRecoveryExplanation =
        "Normal input is unchanged. Retry Now retries the current wanted Keyboard Assignment. Later Activation Activity can also start a new request."
    static let unavailableKeyboardAssignmentRecoveryExplanation =
        "The saved Keyboard Assignment remains. Change Assignment or Remove Assignment. Switching restores automatically only when the exact saved Input Source identifier returns."
    static let manualDesignationButtonTitle = "Manual Physical Keyboard Designation…"
    static let manualDesignationConfirmNameButtonTitle = "Confirm Physical Keyboard Name"
    static let manualDesignationCancelButtonTitle = "Cancel Designation"
    static let manualDesignationAwaitingRemovalMessage =
        "Unplug or turn off this Physical Keyboard, then return it."
    static let manualDesignationAwaitingReturnMessage =
        "Return the same Physical Keyboard to continue."
    static let manualDesignationAwaitingNameMessage =
        "Confirm the Physical Keyboard Name to save Manual Physical Keyboard Designation."
    static let manualDesignationNameFieldLabel = "Physical Keyboard Name"
    static let manualDesignationExplanation =
        "Keyameleon can save this external identity group as a Physical Keyboard only after it leaves, returns, and you confirm its name."


    static let diagnosticsSettingsSectionTitle = "Diagnostics"
    static let startDiagnosticSessionButtonTitle = "Start Diagnostic Session"
    static let stopDiagnosticSessionButtonTitle = "Stop Diagnostic Session"
    static let clearAllDiagnosticDataButtonTitle = "Clear All Diagnostic Data"
    static let diagnosticSessionStatusLabel = "Diagnostic Session"
    static let diagnosticSessionActiveStatus = "Active (ends automatically after 10 minutes)"
    static let diagnosticSessionInactiveStatus = "Inactive"
    static let diagnosticBundleReviewTitle = "Review Diagnostic Bundle"
    static let diagnosticBundleReviewExplanation =
        "Review included Diagnostic Data and exclusions before you save or share. Each action is explicit."
    static let diagnosticBundleIncludedCategoriesLabel = "Included categories"
    static let diagnosticBundleExcludedDataLabel = "Excluded sensitive data"
    static let diagnosticBundleNoIncludedCategories = "None"
    static let diagnosticBundleDateRangeLabel = "Date range"
    static let diagnosticBundleRecordCountLabel = "Record count"
    static let diagnosticBundleSizeLabel = "Size"
    static let diagnosticBundleNoData = "No Diagnostic Data retained."
    static let diagnosticBundleNoDateRange = "No records"
    static let saveDiagnosticBundleButtonTitle = "Save Diagnostic Bundle…"
    static let shareDiagnosticBundleButtonTitle = "Share Diagnostic Bundle…"
    static let diagnosticBundleDefaultFilename = "Keyameleon-Diagnostic-Bundle"
    static let diagnosticBundleSaveFailedMessage = "Could not save Diagnostic Bundle."
    static let diagnosticBundleSharePreviewTitle = "Diagnostic Bundle"
    static let uncleanExitNoticeTitle = "Keyameleon did not exit cleanly."
    static let uncleanExitNoticeMessage =
        "Review local Diagnostic Data. Keyameleon sends no notification for an unclean exit."
    static let reviewDiagnosticsMenuItemTitle = "Review Diagnostics…"
    static let dismissDiagnosticsNoticeMenuItemTitle = "Dismiss Diagnostics Notice"
    static let diagnosticsSettingsFooter =
        "Diagnostic Data uses a closed allowlist. It never includes Key Content, exact Physical Keyboard Identity values, serial numbers, custom names, Keyboard Assignments, Input Source identifiers, paths, user names, or application names. Retention stops at 7 days or 5 MB."

    static func diagnosticDataSummary(recordCount: Int, byteCount: Int) -> String {
        "\(recordCount) records · about \(byteCount) bytes retained"
    }

    static func switchingStatusMenuItemTitle(_ status: SwitchingStatus) -> String {
        "\(switchingStatusMenuItemPrefix) \(status.displayName)"
    }

    static func activePhysicalKeyboardMenuItemTitle(_ value: String) -> String {
        "\(activePhysicalKeyboardMenuItemPrefix) \(value)"
    }

    static func keyboardAssignmentMenuItemTitle(_ value: String) -> String {
        "\(keyboardAssignmentMenuItemPrefix) \(value)"
    }

    static func currentInputSourceMenuItemTitle(_ value: String) -> String {
        "\(currentInputSourceMenuItemPrefix) \(value)"
    }

    static func switchingStatusReasonMenuItemTitle(_ reason: SwitchingUnavailableReason) -> String {
        "\(switchingStatusReasonMenuItemPrefix) \(reason.displayName)"
    }
}
