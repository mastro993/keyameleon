import SwiftUI

/// The General pane: app preferences that apply to Keyameleon as a whole.
@MainActor
struct GeneralSettingsPane: View {
    let model: GeneralSettingsModel

    var body: some View {
        Form {
            Section {
                Toggle(isOn: launchAtLoginBinding) {
                    Text("Launch at login")
                        .font(Theme.Typography.rowTitle)
                        .foregroundStyle(Theme.primary)
                }
                .toggleStyle(.switch)
            } header: {
                Text("App")
                    .font(Theme.Typography.sectionTitle)
                    .foregroundStyle(Theme.primary)
            } footer: {
                LaunchAtLoginFooter(hasError: model.launchAtLoginError != nil)
            }

            Section {
                Picker(selection: externalChangeResponseBinding) {
                    Text("Switch back on the next key press").tag(ExternalChangeResponse.switchBack)
                    Text("Keep it until you type on a matching keyboard").tag(ExternalChangeResponse.holdUntilMatch)
                    Text("Keep it until you type on another keyboard")
                        .tag(ExternalChangeResponse.holdUntilKeyboardChange)
                } label: {
                    Text("When the input source changes outside Keyameleon")
                        .font(Theme.Typography.rowTitle)
                        .foregroundStyle(Theme.primary)
                }
            } header: {
                Text("Switching")
                    .font(Theme.Typography.sectionTitle)
                    .foregroundStyle(Theme.primary)
            } footer: {
                ExternalChangeResponseFooter(response: model.externalChangeResponse)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Theme.contentBackground)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
