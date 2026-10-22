import AppKit
import SwiftUI

/// The About pane: information rows, acknowledgements, and credit.
@MainActor
struct AboutSettingsPane: View {
    let model: GeneralSettingsModel
    let info: AboutInfo

    init(model: GeneralSettingsModel, info: AboutInfo = .current) {
        self.model = model
        self.info = info
    }

    var body: some View {
        Form {
            Section {
                AboutInformationRow(label: .aboutVersion) {
                    Text(info.identity.aboutVersionLabel)
                        .foregroundStyle(Theme.secondary)
                }
                AboutInformationRow(label: .aboutSourceCode) {
                    Link(destination: info.repositoryURL) {
                        AboutLinkLabel(title: .aboutViewOnGitHub, systemImage: "arrow.up.right")
                    }
                    .help(Text(.aboutViewOnGitHubHelp))
                }
                AboutFolderRow(
                    label: .aboutAppDataFolder,
                    url: info.appDataFolderURL,
                    openFolder: openFolder
                )
                .help(Text(.aboutAppDataFolderHelp))
                AboutFolderRow(
                    label: .aboutLogsFolder,
                    url: info.logsFolderURL,
                    openFolder: openFolder
                )
                .help(Text(.aboutLogsFolderHelp))
                AboutInformationRow(label: .aboutLicense) {
                    licenseButton(for: .project, title: LocalizedStringResource(stringLiteral: "MIT"))
                        .help(Text(.aboutLicenseHelp))
                }
                AboutInformationRow(label: .aboutUpdates) {
                    Button(action: model.checkForUpdates) {
                        AboutLinkLabel(title: .checkForUpdates)
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.canCheckForUpdates)
                    .help(Text(.aboutCheckForUpdatesHelp))
                }
            } header: {
                AboutSectionHeading(title: .aboutInformation)
            }
            Section {
                AboutInformationRow(label: LocalizedStringResource(stringLiteral: "Sparkle")) {
                    licenseButton(for: .sparkle, title: .aboutViewLicense)
                }
            } header: {
                AboutSectionHeading(title: .aboutAcknowledgements)
            } footer: {
                AboutCreatorCredit()
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Theme.contentBackground)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// A bundled license text, or a disabled label when the build does not carry it.
    private func licenseButton(
        for license: BundledLicense,
        title: LocalizedStringResource
    ) -> some View {
        Button {
            license.open()
        } label: {
            AboutLinkLabel(title: title, systemImage: "chevron.forward")
        }
        .buttonStyle(.plain)
        .disabled(license.url == nil)
    }

    private func openFolder(_ url: URL) {
        try? FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        NSWorkspace.shared.open(url)
    }
}

#if DEBUG
#Preview("About pane") {
    AboutSettingsPane(
        model: PreviewFixtures.general(),
        info: PreviewFixtures.aboutInfo
    )
    .frame(width: 620, height: 620)
}

#Preview("About pane updates disabled") {
    AboutSettingsPane(
        model: PreviewFixtures.general(canCheckForUpdates: false),
        info: PreviewFixtures.aboutInfo
    )
    .frame(width: 620, height: 620)
    .preferredColorScheme(.dark)
}

#Preview("About pane large text") {
    AboutSettingsPane(
        model: PreviewFixtures.general(),
        info: PreviewFixtures.aboutInfo
    )
    .frame(width: 620, height: 620)
    .environment(\.dynamicTypeSize, .xxxLarge)
}
#endif
