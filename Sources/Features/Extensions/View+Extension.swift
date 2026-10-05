import AppKit
import SwiftUI

extension View {
    /// Applies a modifier only when `value` is present.
    @ViewBuilder
    func ifLet<Value, Content: View>(
        _ value: Value?,
        if ifTransform: @escaping (Self, Value) -> Content
    ) -> some View {
        if let value {
            ifTransform(self, value)
        } else {
            self
        }
    }

    /// Shows the pointing hand while the pointer is over this view.
    ///
    /// SwiftUI gives a `Link` no cursor of its own on macOS, so a link and a
    /// button that opens a folder or a license would otherwise look the same as
    /// plain text. The pushed cursor is popped on exit and on disappear, so a
    /// link that leaves the hierarchy cannot strand the hand.
    func pointingHandCursor() -> some View {
        modifier(PointingHandCursor())
    }
}

@MainActor
private struct PointingHandCursor: ViewModifier {
    /// A disabled link must not advertise itself with a hand.
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    @State private var isPushed = false

    func body(content: Content) -> some View {
        content
            .onHover { isHovered = $0 }
            .onChange(of: showsHand) { _, _ in updateCursor() }
            .onDisappear { pop() }
    }

    private var showsHand: Bool {
        isHovered && isEnabled
    }

    private func updateCursor() {
        if showsHand, !isPushed {
            NSCursor.pointingHand.push()
            isPushed = true
        } else if !showsHand, isPushed {
            pop()
        }
    }

    private func pop() {
        guard isPushed else {
            return
        }
        NSCursor.pop()
        isPushed = false
    }
}
