import AppKit
import SwiftUI

@MainActor
struct KeyameleonSettingsView: View {
    @ObservedObject private var model: KeyameleonGeneralSettingsModel
    private let setupModel: KeyameleonSetupModel
    @Bindable private var selection: KeyameleonSettingsSelection

    init(
        model: KeyameleonGeneralSettingsModel,
        setupModel: KeyameleonSetupModel,
        selection: KeyameleonSettingsSelection
    ) {
        _model = ObservedObject(wrappedValue: model)
        self.setupModel = setupModel
        self.selection = selection
    }

    var body: some View {
        TabView(selection: $selection.section) {
            Tab(
                KeyameleonSettingsSection.general.title,
                systemImage: KeyameleonSettingsSection.general.systemImage,
                value: KeyameleonSettingsSection.general
            ) {
                settingsPane(.general) {
                    KeyameleonGeneralSettingsPane(model: model)
                }
            }
            Tab(
                KeyameleonSettingsSection.keyboards.title,
                systemImage: KeyameleonSettingsSection.keyboards.systemImage,
                value: KeyameleonSettingsSection.keyboards
            ) {
                settingsPane(.keyboards) {
                    KeyameleonKeyboardSettingsView(model: setupModel)
                }
            }
            Tab(
                KeyameleonSettingsSection.about.title,
                systemImage: KeyameleonSettingsSection.about.systemImage,
                value: KeyameleonSettingsSection.about
            ) {
                settingsPane(.about) {
                    KeyameleonAboutView(model: model)
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .frame(minWidth: 720, minHeight: 540)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: model.refresh)
    }

    private func settingsPane<Content: View>(
        _ section: KeyameleonSettingsSection,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(section.title)
                    .font(.largeTitle)
                    .accessibilityAddTraits(.isHeader)
                Text(section.subtitle)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 16)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

@MainActor
private struct KeyameleonGeneralSettingsPane: View {
    @ObservedObject var model: KeyameleonGeneralSettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                SettingsCard(title: "Startup") {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle("Launch Keyameleon at login", isOn: launchAtLoginBinding)
                            .toggleStyle(.switch)

                        if model.launchAtLoginError != nil {
                            Divider()
                            Text(
                                "Could not change Launch at Login. Open System Settings → General → Login Items if macOS requires approval."
                            )
                            .font(.callout)
                            .foregroundStyle(.red)
                        }
                    }
                } footer: {
                    Text("Starts Keyameleon when you log in.")
                }

                SettingsCard(title: "Operational Notifications") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Authorization")
                            Spacer()
                            Text(notificationAuthorizationName(model.notificationAuthorizationState))
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Notification Authorization")
                        .accessibilityValue(
                            notificationAuthorizationName(model.notificationAuthorizationState)
                        )

                        Divider()

                        HStack {
                            if model.notificationAuthorizationState == .notDetermined {
                                Button("Enable Notifications") {
                                    model.requestOperationalNotificationAuthorization()
                                }
                            }

                            Spacer()

                            Button("Open System Settings…") {
                                model.openNotificationSettings()
                            }
                        }
                    }
                } footer: {
                    Text(
                        "Optional alerts for revoked Input Monitoring permission or unavailable Keyboard Assignments. Keyameleon never requests sound or badge access."
                    )
                }

                SettingsCard(title: "Diagnostic Session") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Status")
                            Spacer()
                            Text(model.isDiagnosticSessionActive
                                ? "Active · ends after 10 minutes"
                                : "Inactive")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Diagnostic Session")
                        .accessibilityValue(
                            model.isDiagnosticSessionActive
                                ? "Active, ends automatically after 10 minutes"
                                : "Inactive"
                        )

                        Divider()

                        HStack {
                            Button(model.isDiagnosticSessionActive
                                ? "Stop Diagnostic Session"
                                : "Start Diagnostic Session") {
                                if model.isDiagnosticSessionActive {
                                    model.stopDiagnosticSession()
                                } else {
                                    model.startDiagnosticSession()
                                }
                            }

                            Spacer()

                            Text(
                                "\(model.diagnosticRecordCount) records · about \(model.diagnosticEstimatedByteCount) bytes"
                            )
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        }

                        Divider()

                        Button("Clear All Diagnostic Data", role: .destructive) {
                            model.clearAllDiagnosticData()
                        }
                        .disabled(model.diagnosticRecordCount == 0)
                    }
                } footer: {
                    Text(
                        "Retention stops at 7 days or 5 MB. Diagnostic Data never includes Key Content, serial numbers, custom names, assignments, paths, user names, or application names."
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Diagnostic Bundle")
                        .font(.title3.weight(.semibold))
                    KeyameleonDiagnosticBundleReviewView(model: model)
                }
            }
            .padding(28)
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
