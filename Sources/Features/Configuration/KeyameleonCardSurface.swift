import SwiftUI

/// The card surface the Keyboards settings pane draws one item on.
@MainActor
struct KeyameleonCardSurface: ViewModifier {
    var isHighlighted = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isHighlighted ? AnyShapeStyle(.tint.opacity(0.12)) : AnyShapeStyle(.primary.opacity(0.06)),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
    }
}

extension View {
    func keyameleonCard(isHighlighted: Bool = false) -> some View {
        modifier(KeyameleonCardSurface(isHighlighted: isHighlighted))
    }
}
