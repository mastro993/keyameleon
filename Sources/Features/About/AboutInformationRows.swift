import SwiftUI

/// One label and its trailing value or action on the About pane's information card.
@MainActor
struct AboutInformationRow<Content: View>: View {
    let label: String
    var showsSeparator = true
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.primary)
            Spacer(minLength: 12)
            content
        }
        .padding(.vertical, 11)
        .frame(minHeight: Theme.Metrics.informationRowMinHeight)
        .overlay(alignment: .bottom) {
            if showsSeparator {
                Theme.border.frame(height: 1)
            }
        }
        .padding(.horizontal, Theme.Metrics.informationRowInset)
    }
}

/// One folder the About pane shows the path of and opens in Finder.
@MainActor
struct AboutFolderRow: View {
    let label: String
    let url: URL
    var showsSeparator = true
    let openFolder: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.primary)
            HStack(spacing: 12) {
                Text(url.path)
                    .font(Theme.Typography.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .help(url.path)
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.windowBackground, in: .rect(cornerRadius: 5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Theme.border)
                    }
                Button {
                    openFolder(url)
                } label: {
                    AboutLinkLabel(title: "Open in Finder", systemImage: "folder")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            if showsSeparator {
                Theme.border.frame(height: 1)
            }
        }
        .padding(.horizontal, Theme.Metrics.informationRowInset)
    }
}

#if DEBUG
#Preview("About information rows") {
    InsetGroup(
        cornerRadius: Theme.Metrics.informationGroupRadius,
        fill: Theme.cardSurface
    ) {
        AboutInformationRow(label: "Version") {
            Text("9.9.9 (1)").foregroundStyle(Theme.secondary)
        }
        AboutInformationRow(label: "Source code") {
            AboutLinkLabel(title: "View on GitHub", systemImage: "arrow.up.right")
        }
        AboutFolderRow(
            label: "Logs folder",
            url: URL(fileURLWithPath: "/tmp/Keyameleon/PreviewLogs", isDirectory: true),
            openFolder: { _ in }
        )
    }
    .padding(14)
    .background(Theme.contentBackground)
}
#endif
