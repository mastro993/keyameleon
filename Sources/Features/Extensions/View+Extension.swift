import SwiftUI

extension View {
    /// Applies a modifier only when `value` is present.
    @ViewBuilder
    func ifLet<Value, Content: View>(
        _ value: Value?,
        if ifTransform: (Self, Value) -> Content
    ) -> some View {
        if let value {
            ifTransform(self, value)
        } else {
            self
        }
    }
}
