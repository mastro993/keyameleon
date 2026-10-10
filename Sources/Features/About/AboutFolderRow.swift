import SwiftUI

/// One folder the About pane shows the path of and opens in Finder.
@MainActor
struct AboutFolderRow: View {
    let label: String
    let url: URL
    let openFolder: (URL) -> Void

    var body: some View {
        LabeledContent {
            Button("Open in Finder") { openFolder(url) }
        } label: {
            Text(label)
            Text(url.path)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .help(url.path)
        }
    }
}

#if DEBUG
#Preview("About folder row") {
    Form {
        AboutFolderRow(
            label: "Logs folder",
            url: URL(fileURLWithPath: "/tmp/Keyameleon/PreviewLogs", isDirectory: true),
            openFolder: { _ in }
        )
    }
    .formStyle(.grouped)
    .frame(width: 620, height: 160)
}
#endif
