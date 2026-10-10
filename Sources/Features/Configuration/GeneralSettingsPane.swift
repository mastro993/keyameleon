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
                    // The title wraps beside the wide pop-up instead of pushing it to its own line.
                    HStack {
                        Text("When input source changes externally")
                        Spacer()
                        PopUpPicker(
                            accessibilityLabel: "When input source changes externally",
                            options: Self.responses.map { PopUpPicker.Option(title: $0.title) },
                            selectedIndex: Self.responses.firstIndex { $0.response == model.externalChangeResponse },
                            onSelect: { model.setExternalChangeResponse(Self.responses[$0].response) }
                        )
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

    private static let responses: [(response: ExternalChangeResponse, title: String)] = [
        (.switchBack, "Switch back on the next key press"),
        (.holdUntilMatch, "Keep it until you type on a matching keyboard"),
        (.holdUntilKeyboardChange, "Keep it until you type on another keyboard")
    ]
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
