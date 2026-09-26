import SwiftUI

@MainActor
struct PhysicalKeyboardNameSheet: View {
    @Binding var nameDraft: String
    let productName: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Physical Keyboard Name")
                .font(.title2)
                .accessibilityAddTraits(.isHeader)

            Text(
                "Keyameleon shows this name instead of the macOS product name. Clear it to use \(productName) again."
            )
            .foregroundStyle(.secondary)

            TextField(productName, text: $nameDraft)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Physical Keyboard Name")

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: onSave)
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
