import SwiftUI

/// The General pane: app preferences that apply to Keyameleon as a whole.
@MainActor
struct GeneralSettingsPane: View {
    let model: GeneralSettingsModel

    var body: some View {
        Form {
            Section {
                Toggle(isOn: launchAtLoginBinding) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Launch at login")
                            .font(Theme.Typography.rowTitle)
                            .foregroundStyle(Theme.primary)
                        Text("Start Keyameleon automatically when you log in.")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.secondary)
                    }
                }
                .toggleStyle(.switch)
            } header: {
                Text("App")
                    .font(Theme.Typography.sectionTitle)
                    .foregroundStyle(Theme.primary)
            } footer: {
                LaunchAtLoginFooter(hasError: model.launchAtLoginError != nil)
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
}

#if DEBUG
#Preview("General pane") {
    GeneralSettingsPane(
        model: PreviewFixtures.general(launchAtLoginEnabled: true)
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
