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
                GeneralSectionHeader(title: .generalAppSection)
            } footer: {
                LaunchAtLoginFooter(hasError: model.launchAtLoginError != nil)
            }

            Section {
                ForEach(ExternalChangeChoice.all) { choice in
                    ExternalChangeChoiceRow(
                        choice: choice,
                        isSelected: model.externalChangeResponse == choice.response,
                        action: { model.setExternalChangeResponse(choice.response) }
                    )
                    .listRowBackground(Theme.windowBackground)
                }
            } header: {
                GeneralExternalChangeHeader()
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

private struct GeneralSectionHeader: View {
    let title: LocalizedStringResource

    var body: some View {
        Text(title)
            .font(Theme.Typography.sectionTitle)
            .foregroundStyle(Theme.primary)
            .textCase(nil)
    }
}

private struct GeneralExternalChangeHeader: View {
    var body: some View {
        HStack(spacing: 4) {
            Text(.externalChangeTitle)
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(Theme.primary)
            Image(systemName: "questionmark.circle")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.secondary)
                .help(Text(.externalChangeDescription))
                .accessibilityHidden(true)
        }
        .textCase(nil)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview("General pane") {
    GeneralSettingsPane(
        model: PreviewFixtures.general(launchAtLoginEnabled: true)
    )
    .frame(width: 620, height: 540)
}

#Preview("General pane holding until keyboard change") {
    GeneralSettingsPane(
        model: PreviewFixtures.general(externalChangeResponse: .holdUntilKeyboardChange)
    )
    .frame(width: 620, height: 540)
}

#Preview("General pane large text") {
    GeneralSettingsPane(
        model: PreviewFixtures.general(externalChangeResponse: .holdUntilMatch)
    )
    .frame(width: 620, height: 540)
    .environment(\.dynamicTypeSize, .xxxLarge)
}

#Preview("General pane launch error") {
    GeneralSettingsPane(
        model: PreviewFixtures.general(launchAtLoginFailure: true)
    )
    .frame(width: 620, height: 540)
    .preferredColorScheme(.dark)
}
#endif
