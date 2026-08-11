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
                    "Launch at Login",
                    isOn: launchAtLoginBinding
                )
                .accessibilityLabel("Launch at Login")

                if model.launchAtLoginError != nil {
                    Text(
                        "Could not change Launch at Login. Open System Settings → General → Login Items if macOS requires approval."
                    )
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            } header: {
                Text("General")
            } footer: {
                Text(
                    "Starts Keyameleon when you log in. Uses Service Management for the main app only."
                )
                    .foregroundStyle(.secondary)
            }

            Section {
                Text(notificationAuthorizationName(model.notificationAuthorizationState))
                    .font(.callout)
                    .accessibilityLabel("Notification Authorization")
                    .accessibilityValue(notificationAuthorizationName(model.notificationAuthorizationState))

                if model.notificationAuthorizationState == .notDetermined {
                    Button("Enable Operational Notifications") {
                        model.requestOperationalNotificationAuthorization()
                    }
                    .accessibilityLabel("Enable Operational Notifications")
                }

                Button("Open System Settings…") {
                    model.openNotificationSettings()
                }
                .accessibilityLabel("Open System Settings…")
            } header: {
                Text("Optional operational notifications")
            } footer: {
                Text(
                    "Operational notifications are optional. They never block Activity-Triggered Switching. Keyameleon requests alert access only; it does not request sound or icon badge access."
                )
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Check for Updates…") {
                    model.checkForUpdates()
                }
                .disabled(!model.canCheckForUpdates)
                .accessibilityLabel("Check for Updates…")

                Text(
                    "Keyameleon checks for updates at most once every 24 hours on launch. You approve every installation."
                )
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text(
                    "A critical update shows a clear warning. Keyameleon still waits for your approval and never forces an update."
                )
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Updates")
            }

            Section {
                Text(model.isDiagnosticSessionActive
                    ? "Active (ends automatically after 10 minutes)"
                    : "Inactive")
                    .font(.callout)
                    .accessibilityLabel("Diagnostic Session")
                    .accessibilityValue(
                        model.isDiagnosticSessionActive
                            ? "Active (ends automatically after 10 minutes)"
                            : "Inactive"
                    )

                if model.isDiagnosticSessionActive {
                    Button("Stop Diagnostic Session") {
                        model.stopDiagnosticSession()
                    }
                    .accessibilityLabel("Stop Diagnostic Session")
                } else {
                    Button("Start Diagnostic Session") {
                        model.startDiagnosticSession()
                    }
                    .accessibilityLabel("Start Diagnostic Session")
                }

                Text(
                    "\(model.diagnosticRecordCount) records · about \(model.diagnosticEstimatedByteCount) bytes retained"
                )
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button("Clear All Diagnostic Data", role: .destructive) {
                    model.clearAllDiagnosticData()
                }
                .disabled(model.diagnosticRecordCount == 0)
                .accessibilityLabel("Clear All Diagnostic Data")

                KeyameleonDiagnosticBundleReviewView(model: model)
            } header: {
                Text("Diagnostics")
            } footer: {
                Text(
                    "Diagnostic Data uses a closed allowlist. It never includes Key Content, exact Physical Keyboard Identity values, serial numbers, custom names, Keyboard Assignments, Input Source identifiers, paths, user names, or application names. Retention stops at 7 days or 5 MB."
                )
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

    private func notificationAuthorizationName(
        _ state: OperationalNotificationAuthorizationState
    ) -> String {
        switch state {
        case .unknown:
            "Checking"
        case .notDetermined:
            "Not requested"
        case .denied:
            "Denied"
        case .authorized:
            "Authorized"
        }
    }
}
