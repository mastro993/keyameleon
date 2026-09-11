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
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                aboutSectionTitle("Information")

                VStack(spacing: 0) {
                    aboutRow(
                        title: "Version",
                        help: "Installed Keyameleon version."
                    ) {
                        Text(info.identity.versionLabel)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    rowDivider

                    aboutRow(
                        title: "Source Code",
                        help: "Opens Keyameleon's source repository on GitHub."
                    ) {
                        Button("View on GitHub") {
                            NSWorkspace.shared.open(info.repositoryURL)
                        }
                        .buttonStyle(.bordered)
                    }
                    rowDivider

                    folderRow(
                        title: "App Data Folder",
                        help: "Contains Keyameleon's local application data.",
                        url: info.appDataFolderURL
                    )
                    rowDivider

                    folderRow(
                        title: "Logs Folder",
                        help: "Contains Keyameleon's local log files.",
                        url: info.logsFolderURL
                    )
                    rowDivider

                    aboutRow(
                        title: "License",
                        help: "Keyameleon is distributed under GPL-3.0-only."
                    ) {
                        Text("GPL-3.0-only")
                            .foregroundStyle(.secondary)
                    }
                    rowDivider

                    aboutRow(
                        title: "Updates",
                        help: "Checks whether a newer Keyameleon version is available."
                    ) {
                        Button("Check for Updates…", action: model.checkForUpdates)
                            .disabled(!model.canCheckForUpdates)
                    }
                }
                .background(
                    Color(nsColor: .controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }

                aboutSectionTitle("Acknowledgements")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Sparkle")
                        .font(.body.weight(.semibold))
                    Text("User-approved software updates are powered by Sparkle.")
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color(nsColor: .controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var rowDivider: some View {
        Divider()
            .padding(.horizontal, 20)
    }

    private func aboutSectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }

    private func aboutRow<Content: View>(
        title: String,
        help: String,
        @ViewBuilder value: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            aboutLabel(title, help: help)
            Spacer(minLength: 16)
            value()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func folderRow(title: String, help: String, url: URL) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            aboutLabel(title, help: help)

            HStack(spacing: 8) {
                Text(url.path)
                    .font(.system(.callout, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .help(url.path)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        Color(nsColor: .textBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    }

                Button("Open") {
                    openFolder(url)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func aboutLabel(_ title: String, help: String) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .labelStyle(.titleAndIcon)
        .help(help)
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
#endif
