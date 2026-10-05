import SwiftUI

/// The General pane: app preferences that apply to Keyameleon as a whole.
@MainActor
struct GeneralSettingsPane: View {
    let model: GeneralSettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Metrics.paneSpacing) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("App")
                        .font(.headline)
                        .bold()
                        .foregroundStyle(Theme.primary)

                    launchAtLoginSetting
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Keyameleon runs quietly in your menu bar.")
                        .font(.callout)
                        .foregroundStyle(Theme.secondary)

                    if model.launchAtLoginError != nil {
                        Text(
                            """
                            Could not change Launch at Login. Open System Settings → General → \
                            Login Items if macOS requires approval.
                            """
                        )
                        .font(.callout)
                        .foregroundStyle(.red)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Metrics.panePadding)
        }
    }

    private var launchAtLoginSetting: some View {
        InsetGroup(
            cornerRadius: Theme.Metrics.informationGroupRadius,
            fill: Theme.cardSurface
        ) {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Launch at login")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.primary)
                    Text("Start Keyameleon automatically when you log in.")
                        .font(.callout)
                        .foregroundStyle(Theme.secondary)
                }
                Spacer(minLength: 0)
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(16)
        }
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
    .background(Theme.contentBackground)
}

#Preview("General pane launch error") {
    GeneralSettingsPane(
        model: PreviewFixtures.general(launchAtLoginFailure: true)
    )
    .frame(width: 620, height: 400)
    .background(Theme.contentBackground)
    .preferredColorScheme(.dark)
}
#endif
