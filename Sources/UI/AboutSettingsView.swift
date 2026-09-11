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

                LabeledContent("App Data Folder") {
                    HStack(spacing: 8) {
                        Text(info.appDataFolderURL.path)
                            .font(.system(.callout, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                            .help(info.appDataFolderURL.path)
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
                            openFolder(info.appDataFolderURL)
                        }
                    }
                }
                .help("Contains Keyameleon's local application data.")

                LabeledContent("Logs Folder") {
                    HStack(spacing: 8) {
                        Text(info.logsFolderURL.path)
                            .font(.system(.callout, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                            .help(info.logsFolderURL.path)
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
                            openFolder(info.logsFolderURL)
                        }
                    }
                }
                .help("Contains Keyameleon's local log files.")

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

            Section {
                LabeledContent("Status") {
                    Text(model.isDiagnosticSessionActive
                        ? "Active · ends after 10 minutes"
                        : "Inactive")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Diagnostic Session")
                .accessibilityValue(
                    model.isDiagnosticSessionActive
                        ? "Active, ends automatically after 10 minutes"
                        : "Inactive"
                )

                Button(model.isDiagnosticSessionActive
                    ? "Stop Diagnostic Session"
                    : "Start Diagnostic Session") {
                    if model.isDiagnosticSessionActive {
                        model.stopDiagnosticSession()
                    } else {
                        model.startDiagnosticSession()
                    }
                }

                LabeledContent("Stored Data") {
                    Text(
                        "\(model.diagnosticRecordCount) records · about \(model.diagnosticEstimatedByteCount) bytes"
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Diagnostic Data")
                .accessibilityValue(
                    "\(model.diagnosticRecordCount) records, about \(model.diagnosticEstimatedByteCount) bytes"
                )

                Button("Clear All Diagnostic Data", role: .destructive) {
                    model.clearAllDiagnosticData()
                }
                .disabled(model.diagnosticRecordCount == 0)
            } header: {
                Text("Diagnostics")
            } footer: {
                Text(
                    "Retention stops at 7 days or 5 MB. Diagnostic Data never includes Key Content, serial numbers, custom names, assignments, paths, user names, or application names."
                )
            }

            KeyameleonDiagnosticBundleReviewView(model: model)

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

#Preview("About with diagnostics") {
    KeyameleonAboutView(
        model: KeyameleonPreviewFixtures.generalWithDiagnosticData(),
        info: KeyameleonPreviewFixtures.aboutInfo
    )
    .environment(\.dynamicTypeSize, .xxxLarge)
}
#endif
