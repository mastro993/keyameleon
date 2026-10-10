import SwiftUI

/// The General pane: app preferences that apply to Keyameleon as a whole.
@MainActor
struct GeneralSettingsPane: View {
    let model: GeneralSettingsModel

    var body: some View {
        Form {
            Section("App") {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                    .toggleStyle(.switch)
                if model.launchAtLoginError != nil {
                    LaunchAtLoginErrorRow()
                }
            }

            Section {
                VStack(alignment: .leading) {
                    Picker("When input source changes externally", selection: externalChangeResponseBinding) {
                        Text("Switch back on the next key press").tag(ExternalChangeResponse.switchBack)
                        Text("Keep it until you type on a matching keyboard").tag(ExternalChangeResponse.holdUntilMatch)
                        Text("Keep it until you type on another keyboard")
                            .tag(ExternalChangeResponse.holdUntilKeyboardChange)
                    }
                    // Full width under the row, like System Settings descriptions.
                    Text("What happens after a shortcut, the menu bar, or another app changes the input source.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } header: {
                Text("Switching")
            } footer: {
                ExternalChangeResponseFooter(response: model.externalChangeResponse)
            }
        }
        .formStyle(.grouped)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.isLaunchAtLoginEnabled },
            set: { model.setLaunchAtLoginEnabled($0) }
        )
    }

    private var externalChangeResponseBinding: Binding<ExternalChangeResponse> {
        Binding(
            get: { model.externalChangeResponse },
            set: { model.setExternalChangeResponse($0) }
        )
    }
}

#if DEBUG
#Preview("General pane") {
    GeneralSettingsPane(
        model: PreviewFixtures.general(launchAtLoginEnabled: true)
    )
    .frame(width: 620, height: 400)
}

#Preview("General pane holding until keyboard change") {
    GeneralSettingsPane(
        model: PreviewFixtures.general(externalChangeResponse: .holdUntilKeyboardChange)
    )
    .frame(width: 620, height: 400)
}

#Preview("General pane launch error") {
    GeneralSettingsPane(
        model: PreviewFixtures.general(launchAtLoginFailure: true)
    )
    .frame(width: 620, height: 400)
    .preferredColorScheme(.dark)
}
#endif
