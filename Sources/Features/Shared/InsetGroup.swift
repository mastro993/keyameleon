import SwiftUI

/// The inset group surface Shared flows draw rows on.
///
/// The Keyboards list and Guided setup use the larger radius on the window
/// surface; Settings information rows use the smaller radius on the card
/// surface. Rows draw their own separators with `keyameleonGroupSeparator`.
@MainActor
struct InsetGroup<Content: View>: View {
    var cornerRadius = Theme.Metrics.groupRadius
    var fill = Theme.windowBackground
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(fill, in: .rect(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Theme.border)
        }
    }
}

#if DEBUG
#Preview("Inset group") {
    InsetGroup {
        Text("First row")
            .padding(Theme.Metrics.settingsKeyboardRowPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .keyameleonGroupSeparator(
                false,
                inset: Theme.Metrics.settingsKeyboardRowPadding.leading
            )
        Text("Second row")
            .padding(Theme.Metrics.settingsKeyboardRowPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .keyameleonGroupSeparator(
                true,
                inset: Theme.Metrics.settingsKeyboardRowPadding.leading
            )
    }
    .padding()
    .background(Theme.contentBackground)
}
#endif
