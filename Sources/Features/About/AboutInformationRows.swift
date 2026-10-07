import SwiftUI

@MainActor
struct AboutInformationRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        LabeledContent(label) {
            content
        }
        .font(Theme.Typography.body)
        .foregroundStyle(Theme.primary)
    }
}

/// One folder the About pane shows the path of and opens in Finder.
@MainActor
struct AboutFolderRow: View {
    let label: String
    let url: URL
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
                    .padding(.vertical, 4)
                    .frame(minHeight: 28)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 7)
    }
}

#if DEBUG
#Preview("About information rows") {
    Form {
        Section {
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
    }
    .formStyle(.grouped)
    .frame(width: 620, height: 260)
}
#endif
