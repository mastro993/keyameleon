import AppKit
import SwiftUI

/// The About pane: app identity, information rows, acknowledgements, and credit.
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
                AboutInformationRow(label: "Version") {
                    Text(info.identity.aboutVersionLabel)
                        .foregroundStyle(Theme.secondary)
                }
                AboutInformationRow(label: "Source code") {
                    Link(destination: info.repositoryURL) {
                        AboutLinkLabel(title: "View on GitHub", systemImage: "arrow.up.right")
                    }
                    .help("Opens Keyameleon's source repository on GitHub.")
                }
                AboutFolderRow(
                    label: "App data folder",
                    url: info.appDataFolderURL,
                    openFolder: openFolder
                )
                .help("Contains Keyameleon's local application data.")
                AboutFolderRow(
                    label: "Logs folder",
                    url: info.logsFolderURL,
                    openFolder: openFolder
                )
                .help("Contains Keyameleon's local log files.")
                AboutInformationRow(label: "License") {
                    licenseButton(for: .project, title: "MIT")
                        .help("Opens the MIT License.")
                }
                AboutInformationRow(label: "Updates") {
                    Button(action: model.checkForUpdates) {
                        AboutLinkLabel(title: "Check for Updates…")
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.canCheckForUpdates)
                    .help("Checks whether a newer Keyameleon version is available.")
                }
            } header: {
                VStack(alignment: .leading, spacing: 16) {
                    AboutIdentityBlock(info: info)
                    AboutSectionHeading(title: "Information")
                }
            }
            Section {
                AboutInformationRow(label: "Sparkle") {
                    licenseButton(for: .sparkle, title: "View License")
                }
            } header: {
                AboutSectionHeading(title: "Acknowledgements")
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
        title: String
    ) -> some View {
        Button {
            license.open()
        } label: {
            AboutLinkLabel(title: title, systemImage: "chevron.right")
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
