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
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 420, minHeight: 280)
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
