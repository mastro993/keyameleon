import SwiftUI

@MainActor
struct ManualPhysicalKeyboardDesignationNameSheet: View {
    @Binding var nameDraft: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Confirm Physical Keyboard Name")
                .font(.title2)

            Text(
                "Keyameleon can save this external identity group as a Physical Keyboard only after it leaves, returns, and you confirm its name."
            )
                .foregroundStyle(.secondary)

            Text("Physical Keyboard Name")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(
                "Physical Keyboard Name",
                text: $nameDraft
            )
            .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel Designation", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Confirm Physical Keyboard Name") {
                    onConfirm()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 360)
    }
}

#if DEBUG
#Preview("Manual designation valid name") {
    @Previewable @State var nameDraft = "Studio Keyboard"
    ManualPhysicalKeyboardDesignationNameSheet(
        nameDraft: $nameDraft,
        onConfirm: {},
        onCancel: {}
    )
}

#Preview("Manual designation empty name") {
    @Previewable @State var nameDraft = ""
    ManualPhysicalKeyboardDesignationNameSheet(
        nameDraft: $nameDraft,
        onConfirm: {},
        onCancel: {}
    )
    .preferredColorScheme(.dark)
}
#endif
