import SwiftUI

@MainActor
struct PhysicalKeyboardNameSheet: View {
    @Binding var nameDraft: String
    let productName: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(.renameKeyboardTitle)
                .font(.title2)
                .accessibilityAddTraits(.isHeader)

            Text(.renameKeyboardHint(productName))
            .foregroundStyle(.secondary)

            TextField(productName, text: $nameDraft)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(.renameKeyboardNameLabel)

            HStack {
                Spacer()
                Button(.cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(.save, action: onSave)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 360)
    }
}

#if DEBUG
#Preview("Physical Keyboard Name custom") {
    @Previewable @State var nameDraft = "Travel"
    PhysicalKeyboardNameSheet(
        nameDraft: $nameDraft,
        productName: "Keychron K2",
        onSave: {},
        onCancel: {}
    )
}

#Preview("Physical Keyboard Name cleared") {
    @Previewable @State var nameDraft = ""
    PhysicalKeyboardNameSheet(
        nameDraft: $nameDraft,
        productName: "Keychron K2",
        onSave: {},
        onCancel: {}
    )
}
#endif
