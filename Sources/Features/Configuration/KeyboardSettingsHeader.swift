import SwiftUI

@MainActor
struct KeyboardSettingsHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keyboard layouts")
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(Theme.primary)
            Text("Choose a layout for each keyboard. Keyameleon switches when you type.")
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
