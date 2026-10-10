import SwiftUI

@MainActor
struct KeyboardSettingsHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Input sources")
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(Theme.primary)
            Text("Keyameleon switches to a keyboard’s input source when you type on it.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.secondary)
        }
        .textCase(nil)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview("Keyboard settings header") {
    KeyboardSettingsHeader()
        .padding(16)
        .frame(width: 620)
        .background(Theme.contentBackground)
}
#endif
