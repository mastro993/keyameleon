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
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Metrics.paneSpacing) {
                identity
                information
                acknowledgements
                creatorCredit
            }
            .padding(Theme.Metrics.panePadding)
        }
    }

    private var identity: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 48, height: 48)
                .accessibilityLabel("Keyameleon app icon")
            VStack(alignment: .leading, spacing: 5) {
                Text(info.identity.name)
                    .font(Theme.Typography.screenTitle)
                    .foregroundStyle(Theme.primary)
                Text("The right layout. On every keyboard.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.secondary)
            }
        }
    }

    private var information: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Information")
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(Theme.primary)
            InsetGroup(
                cornerRadius: Theme.Metrics.informationGroupRadius,
                fill: Theme.cardSurface
            ) {
                AboutInformationRow(label: "Version") {
                    Text(info.identity.aboutVersionLabel)
                        .foregroundStyle(Theme.secondary)
                        .help("Installed Keyameleon version.")
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
                        .help("Keyameleon is distributed under MIT.")
                }
                AboutInformationRow(label: "Updates", showsSeparator: false) {
                    Button(action: model.checkForUpdates) {
                        AboutLinkLabel(title: "Check for Updates…")
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.canCheckForUpdates)
                    .help("Checks whether a newer Keyameleon version is available.")
                }
            }
        }
    }

    private var acknowledgements: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Acknowledgements")
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(Theme.primary)
            InsetGroup(
                cornerRadius: Theme.Metrics.informationGroupRadius,
                fill: Theme.cardSurface
            ) {
                HStack(spacing: 12) {
                    Text("Sparkle")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.primary)
                    Spacer(minLength: 12)
                    licenseButton(for: .sparkle, title: "View full License")
                }
                .padding(.vertical, 14)
                .padding(.horizontal, Theme.Metrics.informationRowInset)
            }
        }
    }

    private var creatorCredit: some View {
        HStack(spacing: 4) {
            Text("Made with ❤️ by")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.secondary)
            Link(destination: AboutInfo.creatorURL) {
                Text("@fedemas")
                    .font(Theme.Typography.caption)
            }
            .pointingHandCursor()
        }
        .frame(maxWidth: .infinity)
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
    .background(Theme.contentBackground)
}

#Preview("About pane updates disabled") {
    AboutSettingsPane(
        model: PreviewFixtures.general(canCheckForUpdates: false),
        info: PreviewFixtures.aboutInfo
    )
    .frame(width: 620, height: 620)
    .background(Theme.contentBackground)
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
