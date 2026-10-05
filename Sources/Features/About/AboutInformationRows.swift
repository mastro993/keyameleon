import SwiftUI

/// One label and its trailing value or action on the About pane's information card.
@MainActor
struct KeyameleonAboutInformationRow<Content: View>: View {
    let label: String
    var showsSeparator = true
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.body)
                .foregroundStyle(KeyameleonTheme.primary)
            Spacer(minLength: 12)
            content
        }
        .padding(.vertical, 11)
        .frame(minHeight: KeyameleonTheme.Metrics.informationRowMinHeight)
        .overlay(alignment: .bottom) {
            if showsSeparator {
                KeyameleonTheme.border.frame(height: 1)
            }
        }
        .padding(.horizontal, KeyameleonTheme.Metrics.informationRowInset)
    }
}

/// One folder the About pane shows the path of and opens in Finder.
@MainActor
struct KeyameleonAboutFolderRow: View {
    let label: String
    let url: URL
    var showsSeparator = true
    let openFolder: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.body)
                .foregroundStyle(KeyameleonTheme.primary)
            HStack(spacing: 12) {
                Text(url.path)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .help(url.path)
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(KeyameleonTheme.windowBackground, in: .rect(cornerRadius: 5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(KeyameleonTheme.border)
                    }
                Button {
                    openFolder(url)
                } label: {
                    KeyameleonAboutLinkLabel(title: "Open in Finder", systemImage: "folder")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            if showsSeparator {
                KeyameleonTheme.border.frame(height: 1)
            }
        }
        .padding(.horizontal, KeyameleonTheme.Metrics.informationRowInset)
    }
}

#if DEBUG
#Preview("About information rows") {
    KeyameleonInsetGroup(
        cornerRadius: KeyameleonTheme.Metrics.informationGroupRadius,
        fill: KeyameleonTheme.cardSurface
    ) {
        KeyameleonAboutInformationRow(label: "Version") {
            Text("9.9.9 (1)").foregroundStyle(KeyameleonTheme.secondary)
        }
        KeyameleonAboutInformationRow(label: "Source code") {
            KeyameleonAboutLinkLabel(title: "View on GitHub", systemImage: "arrow.up.right")
        }
        KeyameleonAboutFolderRow(
            label: "Logs folder",
            url: URL(fileURLWithPath: "/tmp/Keyameleon/PreviewLogs", isDirectory: true),
            openFolder: { _ in }
        )
    }
    .padding(14)
    .background(KeyameleonTheme.contentBackground)
}
#endif
