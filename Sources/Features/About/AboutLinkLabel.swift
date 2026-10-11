import SwiftUI

/// The accent label and trailing symbol the About pane's rows use for actions.
@MainActor
struct AboutLinkLabel: View {
    let title: LocalizedStringResource
    var systemImage: String?

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(Theme.Typography.body)
            if let systemImage {
                Image(systemName: systemImage)
                    .font(Theme.Typography.caption)
            }
        }
        .foregroundStyle(Theme.accent)
        .contentShape(.rect)
        .pointingHandCursor()
    }
}

#if DEBUG
#Preview("About link label") {
    AboutLinkLabel(title: .aboutViewOnGitHub, systemImage: "arrow.up.right")
        .padding()
        .background(Theme.contentBackground)
}
#endif
