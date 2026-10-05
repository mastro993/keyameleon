import AppKit
import SwiftUI

/// The About pane: app identity, information rows, acknowledgements, and credit.
@MainActor
struct KeyameleonAboutSettingsPane: View {
    let model: KeyameleonGeneralSettingsModel
    let info: KeyameleonAboutInfo

    init(model: KeyameleonGeneralSettingsModel, info: KeyameleonAboutInfo = .current) {
        self.model = model
        self.info = info
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KeyameleonTheme.Metrics.paneSpacing) {
                identity
                information
                acknowledgements
            }
            .padding(KeyameleonTheme.Metrics.panePadding)
        }
        .safeAreaInset(edge: .bottom) { creatorCredit }
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
                    .font(.title2)
                    .bold()
                    .foregroundStyle(KeyameleonTheme.primary)
                Text("The right layout. On every keyboard.")
                    .font(.callout)
                    .foregroundStyle(KeyameleonTheme.secondary)
            }
        }
    }

    private var information: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Information")
                .font(.headline)
                .bold()
                .foregroundStyle(KeyameleonTheme.primary)
            KeyameleonInsetGroup(
                cornerRadius: KeyameleonTheme.Metrics.informationGroupRadius,
                fill: KeyameleonTheme.cardSurface
            ) {
                KeyameleonAboutInformationRow(label: "Version") {
                    Text(info.identity.aboutVersionLabel)
                        .foregroundStyle(KeyameleonTheme.secondary)
                        .help("Installed Keyameleon version.")
                }
                KeyameleonAboutInformationRow(label: "Source code") {
                    Link(destination: info.repositoryURL) {
                        KeyameleonAboutLinkLabel(title: "View on GitHub", systemImage: "arrow.up.right")
                    }
                    .help("Opens Keyameleon's source repository on GitHub.")
                }
                KeyameleonAboutFolderRow(
                    label: "App data folder",
                    url: info.appDataFolderURL,
                    openFolder: openFolder
                )
                .help("Contains Keyameleon's local application data.")
                KeyameleonAboutFolderRow(
                    label: "Logs folder",
                    url: info.logsFolderURL,
                    openFolder: openFolder
                )
                .help("Contains Keyameleon's local log files.")
                KeyameleonAboutInformationRow(label: "License") {
                    licenseButton(for: .project, title: "MIT")
                        .help("Keyameleon is distributed under MIT.")
                }
                KeyameleonAboutInformationRow(label: "Updates", showsSeparator: false) {
                    Button(action: model.checkForUpdates) {
                        KeyameleonAboutLinkLabel(title: "Check for Updates…")
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
                .font(.headline)
                .bold()
                .foregroundStyle(KeyameleonTheme.primary)
            KeyameleonInsetGroup(
                cornerRadius: KeyameleonTheme.Metrics.informationGroupRadius,
                fill: KeyameleonTheme.cardSurface
            ) {
                HStack(spacing: 12) {
                    Text("Sparkle")
                        .font(.body)
                        .foregroundStyle(KeyameleonTheme.primary)
                    Spacer(minLength: 12)
                    licenseButton(for: .sparkle, title: "View full License")
                }
                .padding(.vertical, 14)
                .padding(.horizontal, KeyameleonTheme.Metrics.informationRowInset)
            }
        }
    }

    private var creatorCredit: some View {
        HStack(spacing: 4) {
            Text("Made with ❤️ by")
                .font(.callout)
                .foregroundStyle(KeyameleonTheme.secondary)
            Link(destination: KeyameleonAboutInfo.creatorURL) {
                Text("@fedemas")
                    .font(.callout)
            }
        }
        .padding(.bottom, KeyameleonTheme.Metrics.panePadding.bottom)
    }

    /// A bundled license text, or a disabled label when the build does not carry it.
    private func licenseButton(
        for license: KeyameleonBundledLicense,
        title: String
    ) -> some View {
        Button {
            license.open()
        } label: {
            KeyameleonAboutLinkLabel(title: title, systemImage: "chevron.right")
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
    KeyameleonAboutSettingsPane(
        model: KeyameleonPreviewFixtures.general(),
        info: KeyameleonPreviewFixtures.aboutInfo
    )
    .frame(width: 620, height: 620)
    .background(KeyameleonTheme.contentBackground)
}

#Preview("About pane updates disabled") {
    KeyameleonAboutSettingsPane(
        model: KeyameleonPreviewFixtures.general(canCheckForUpdates: false),
        info: KeyameleonPreviewFixtures.aboutInfo
    )
    .frame(width: 620, height: 620)
    .background(KeyameleonTheme.contentBackground)
    .preferredColorScheme(.dark)
}

#Preview("About pane large text") {
    KeyameleonAboutSettingsPane(
        model: KeyameleonPreviewFixtures.general(),
        info: KeyameleonPreviewFixtures.aboutInfo
    )
    .frame(width: 620, height: 620)
    .environment(\.dynamicTypeSize, .xxxLarge)
}
#endif
