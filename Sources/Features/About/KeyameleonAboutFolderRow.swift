import AppKit
import SwiftUI

/// One About row for a folder the user can open. The label sits on its own line
/// so a long path never competes with it for width.
@MainActor
struct KeyameleonAboutFolderRow: View {
    let label: String
    let url: URL
    let help: String
    let openFolder: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text(label)

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
        .help(help)
    }
}

#if DEBUG
#Preview("About folder row") {
    Form {
        KeyameleonAboutFolderRow(
            label: "Logs Folder",
            url: KeyameleonPreviewFixtures.aboutInfo.logsFolderURL,
            help: "Contains Keyameleon's local log files.",
            openFolder: { _ in }
        )
    }
    .formStyle(.grouped)
}
#endif
