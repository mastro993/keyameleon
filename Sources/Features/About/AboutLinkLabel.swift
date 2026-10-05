import SwiftUI

/// The accent label and trailing symbol the About pane's rows use for actions.
@MainActor
struct KeyameleonAboutLinkLabel: View {
    let title: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.body)
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.callout)
            }
        }
        .foregroundStyle(KeyameleonTheme.accent)
        .contentShape(.rect)
    }
}

#if DEBUG
#Preview("About link label") {
    KeyameleonAboutLinkLabel(title: "View on GitHub", systemImage: "arrow.up.right")
        .padding()
        .background(KeyameleonTheme.contentBackground)
}
#endif
