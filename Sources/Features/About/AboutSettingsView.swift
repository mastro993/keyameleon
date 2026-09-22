import AppKit
import SwiftUI

@MainActor
struct KeyameleonAboutView: View {
    @ObservedObject private var model: KeyameleonGeneralSettingsModel
    private let info: KeyameleonAboutInfo

    init(
        model: KeyameleonGeneralSettingsModel,
        info: KeyameleonAboutInfo = .current
    ) {
        _model = ObservedObject(wrappedValue: model)
        self.info = info
    }

    var body: some View {
        Form {
            Section("Information") {
                LabeledContent("Version") {
                    Text(info.identity.versionLabel)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .help("Installed Keyameleon version.")

                LabeledContent("Source Code") {
                    Button("View on GitHub") {
                        NSWorkspace.shared.open(info.repositoryURL)
                    }
                    .buttonStyle(.bordered)
                }
                .help("Opens Keyameleon's source repository on GitHub.")

                KeyameleonAboutFolderRow(
                    label: "App Data Folder",
                    url: info.appDataFolderURL,
                    help: "Contains Keyameleon's local application data.",
                    openFolder: openFolder
                )

                KeyameleonAboutFolderRow(
                    label: "Logs Folder",
                    url: info.logsFolderURL,
                    help: "Contains Keyameleon's local log files.",
                    openFolder: openFolder
                )

                LabeledContent("License") {
                    Text("GPL-3.0-only")
                        .foregroundStyle(.secondary)
                }
                .help("Keyameleon is distributed under GPL-3.0-only.")

                LabeledContent("Updates") {
                    Button("Check for Updates…", action: model.checkForUpdates)
                        .disabled(!model.canCheckForUpdates)
                }
                .help("Checks whether a newer Keyameleon version is available.")
            }

            Section("Acknowledgements") {
                LabeledContent("Sparkle") {
                    Text("User-approved software updates are powered by Sparkle.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
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
#Preview("About updates enabled") {
    KeyameleonAboutView(
        model: KeyameleonPreviewFixtures.general(),
        info: KeyameleonPreviewFixtures.aboutInfo
    )
}

#Preview("About updates disabled") {
    KeyameleonAboutView(
        model: KeyameleonPreviewFixtures.general(canCheckForUpdates: false),
        info: KeyameleonPreviewFixtures.aboutInfo
    )
    .preferredColorScheme(.dark)
}

#Preview("About with large text") {
    KeyameleonAboutView(
        model: KeyameleonPreviewFixtures.general(),
        info: KeyameleonPreviewFixtures.aboutInfo
    )
    .environment(\.dynamicTypeSize, .xxxLarge)
}
#endif
