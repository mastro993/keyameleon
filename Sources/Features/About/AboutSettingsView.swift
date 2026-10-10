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
                LabeledContent("Version", value: info.identity.aboutVersionLabel)
                LabeledContent("Source code") {
                    Link("View on GitHub", destination: info.repositoryURL)
                        .help("Opens Keyameleon's source repository on GitHub.")
                }
                AboutFolderRow(label: "App data folder", url: info.appDataFolderURL, openFolder: openFolder)
                    .help("Contains Keyameleon's local application data.")
                AboutFolderRow(label: "Logs folder", url: info.logsFolderURL, openFolder: openFolder)
                    .help("Contains Keyameleon's local log files.")
                LabeledContent {
                    licenseButton(for: .project)
                } label: {
                    Text("License")
                    Text("MIT")
                }
                LabeledContent("Updates") {
                    Button("Check for Updates…", action: model.checkForUpdates)
                        .disabled(!model.canCheckForUpdates)
                        .help("Checks whether a newer Keyameleon version is available.")
                }
            } header: {
                VStack(alignment: .leading) {
                    AboutIdentityBlock(info: info)
                    Text("Information")
                }
            }
            Section {
                LabeledContent("Sparkle") {
                    licenseButton(for: .sparkle)
                }
            } header: {
                Text("Acknowledgements")
            } footer: {
                AboutCreatorCredit()
            }
        }
        .formStyle(.grouped)
    }

    /// A bundled license text, disabled when the build does not carry it.
    private func licenseButton(for license: BundledLicense) -> some View {
        Button("View License", action: license.open)
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
