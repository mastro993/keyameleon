import SwiftUI

/// The inset group surface Shared flows draw rows on.
///
/// The Keyboards list and Guided setup use the larger radius on the window
/// surface; Settings information rows use the smaller radius on the card
/// surface. Rows draw their own separators with `keyameleonGroupSeparator`.
@MainActor
struct KeyameleonInsetGroup<Content: View>: View {
    var cornerRadius = KeyameleonTheme.Metrics.groupRadius
    var fill = KeyameleonTheme.windowBackground
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(fill, in: .rect(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(KeyameleonTheme.border)
        }
    }
}

#if DEBUG
#Preview("Inset group") {
    KeyameleonInsetGroup {
        Text("First row")
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .keyameleonGroupSeparator(false)
        Text("Second row")
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .keyameleonGroupSeparator(true)
    }
    .padding()
    .background(KeyameleonTheme.contentBackground)
}
#endif
