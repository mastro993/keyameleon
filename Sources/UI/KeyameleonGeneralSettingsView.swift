import SwiftUI

@MainActor
struct KeyameleonGeneralSettingsView: View {
    @ObservedObject private var model: KeyameleonGeneralSettingsModel

    init(model: KeyameleonGeneralSettingsModel) {
        _model = ObservedObject(wrappedValue: model)
    }

    var body: some View {
        Form {
            Section {
                Toggle(
                    KeyameleonAppMetadata.launchAtLoginToggleTitle,
                    isOn: launchAtLoginBinding
                )
                .accessibilityLabel(KeyameleonAppMetadata.launchAtLoginToggleTitle)

                if let errorMessage = model.launchAtLoginErrorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            } header: {
                Text(KeyameleonAppMetadata.generalSettingsTitle)
            } footer: {
                Text(KeyameleonAppMetadata.launchAtLoginFooter)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text(model.notificationAuthorizationState.displayName)
                    .font(.callout)
                    .accessibilityLabel(KeyameleonAppMetadata.notificationAuthorizationLabel)
                    .accessibilityValue(model.notificationAuthorizationState.displayName)

                if model.notificationAuthorizationState == .notDetermined {
                    Button(KeyameleonAppMetadata.enableOperationalNotificationsButtonTitle) {
                        model.requestOperationalNotificationAuthorization()
                    }
                    .accessibilityLabel(KeyameleonAppMetadata.enableOperationalNotificationsButtonTitle)
                }

                Button(KeyameleonAppMetadata.openNotificationSettingsButtonTitle) {
                    model.openNotificationSettings()
                }
                .accessibilityLabel(KeyameleonAppMetadata.openNotificationSettingsButtonTitle)
            } header: {
                Text(KeyameleonAppMetadata.operationalNotificationSetupTitle)
            } footer: {
                Text(KeyameleonAppMetadata.notificationAuthorizationFooter)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(KeyameleonAppMetadata.checkForUpdatesButtonTitle) {
                    model.checkForUpdates()
                }
                .disabled(!model.canCheckForUpdates)
                .accessibilityLabel(KeyameleonAppMetadata.checkForUpdatesButtonTitle)

                Text(KeyameleonAppMetadata.updateApprovalExplanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text(KeyameleonAppMetadata.criticalUpdateWarningExplanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Text(KeyameleonAppMetadata.updatesSettingsSectionTitle)
            }

            Section {
                Text(model.isDiagnosticSessionActive
                    ? KeyameleonAppMetadata.diagnosticSessionActiveStatus
                    : KeyameleonAppMetadata.diagnosticSessionInactiveStatus)
                    .font(.callout)
                    .accessibilityLabel(KeyameleonAppMetadata.diagnosticSessionStatusLabel)
                    .accessibilityValue(
                        model.isDiagnosticSessionActive
                            ? KeyameleonAppMetadata.diagnosticSessionActiveStatus
                            : KeyameleonAppMetadata.diagnosticSessionInactiveStatus
                    )

                if model.isDiagnosticSessionActive {
                    Button(KeyameleonAppMetadata.stopDiagnosticSessionButtonTitle) {
                        model.stopDiagnosticSession()
                    }
                    .accessibilityLabel(KeyameleonAppMetadata.stopDiagnosticSessionButtonTitle)
                } else {
                    Button(KeyameleonAppMetadata.startDiagnosticSessionButtonTitle) {
                        model.startDiagnosticSession()
                    }
                    .accessibilityLabel(KeyameleonAppMetadata.startDiagnosticSessionButtonTitle)
                }

                Text(KeyameleonAppMetadata.diagnosticDataSummary(
                    recordCount: model.diagnosticRecordCount,
                    byteCount: model.diagnosticEstimatedByteCount
                ))
                .font(.callout)
                .foregroundStyle(.secondary)

                Button(KeyameleonAppMetadata.clearAllDiagnosticDataButtonTitle, role: .destructive) {
                    model.clearAllDiagnosticData()
                }
                .disabled(model.diagnosticRecordCount == 0)
                .accessibilityLabel(KeyameleonAppMetadata.clearAllDiagnosticDataButtonTitle)

                KeyameleonDiagnosticBundleReviewView(model: model)
            } header: {
                Text(KeyameleonAppMetadata.diagnosticsSettingsSectionTitle)
            } footer: {
                Text(KeyameleonAppMetadata.diagnosticsSettingsFooter)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 420, minHeight: 360)
        .onAppear {
            model.refresh()
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.isLaunchAtLoginEnabled },
            set: { model.setLaunchAtLoginEnabled($0) }
        )
    }
}
