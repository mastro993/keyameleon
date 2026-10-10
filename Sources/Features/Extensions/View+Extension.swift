import SwiftUI

extension View {
    /// Shows the pointing hand while the pointer is over this view.
    func pointingHandCursor() -> some View {
        modifier(PointingHandCursor())
    }
}

@MainActor
private struct PointingHandCursor: ViewModifier {
    /// A disabled link must not advertise itself with a hand.
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content.pointerStyle(isEnabled ? .link : nil)
    }
}
