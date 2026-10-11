import SwiftUI

/// The General pane: app preferences that apply to Keyameleon as a whole.
@MainActor
struct GeneralSettingsPane: View {
    let model: GeneralSettingsModel

    var body: some View {
        Form {
            Section {
                Toggle(isOn: launchAtLoginBinding) {
                    Text(.launchAtLogin)
                        .font(Theme.Typography.rowTitle)
                        .foregroundStyle(Theme.primary)
                }
                .toggleStyle(.switch)
            } header: {
                Text(.generalAppSection)
                    .font(Theme.Typography.sectionTitle)
                    .foregroundStyle(Theme.primary)
            } footer: {
                LaunchAtLoginFooter(hasError: model.launchAtLoginError != nil)
            }

            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text(.externalChangeTitle)
                            .font(Theme.Typography.rowTitle)
                            .foregroundStyle(Theme.primary)
                        Spacer()
                        PopUpPicker(
                            accessibilityLabel: String(localized: .externalChangeTitle),
                            options: Self.responses.map { PopUpPicker.Option(title: String(localized: $0.title)) },
                            selectedIndex: Self.responses.firstIndex { $0.response == model.externalChangeResponse },
                            onSelect: { model.setExternalChangeResponse(Self.responses[$0].response) }
                        )
                        .fixedSize()
                    }
                    Text(.externalChangeDescription)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } header: {
                Text(.generalSwitchingSection)
                    .font(Theme.Typography.sectionTitle)
                    .foregroundStyle(Theme.primary)
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

    private static let responses: [(response: ExternalChangeResponse, title: LocalizedStringResource)] = [
        (.switchBack, .externalChangeSwitchBack),
        (.holdUntilMatch, .externalChangeHoldUntilMatch),
        (.holdUntilKeyboardChange, .externalChangeHoldUntilKeyboardChange)
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
