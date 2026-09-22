import SwiftUI

private func physicalKeyboardStatusDescription(_ physicalKeyboard: PhysicalKeyboard) -> String {
    switch physicalKeyboard.assignmentState {
    case .unassigned:
        "Unassigned"
    case .assigned:
        "Assigned"
    case let .unsupported(reason):
        switch reason {
        case .missingIdentity:
            "Unsupported — Physical Keyboard Identity unavailable"
        case .unstableIdentity:
            "Unsupported — Physical Keyboard Identity unstable"
        case .sharedIdentity:
            "Unsupported — Physical Keyboard Identity shared"
        case .ambiguousIdentity:
            "Unsupported — Physical Keyboard Identity ambiguous"
        }
    }
}

@MainActor
struct ReplaceSavedPhysicalKeyboardPickerView: View {
    let physicalKeyboard: PhysicalKeyboard
    let candidates: [PhysicalKeyboard]
    let onSelect: (PhysicalKeyboard) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Replace Saved Physical Keyboard")
                .font(.title2)

            Text("Move a disconnected saved Physical Keyboard onto \(physicalKeyboard.name).")
                .foregroundStyle(.secondary)

            if candidates.isEmpty {
                Text("No disconnected saved Physical Keyboards.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List(candidates) { candidate in
                    Button {
                        onSelect(candidate)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(candidate.name)
                            Text(physicalKeyboardStatusDescription(candidate))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 360, minHeight: 360)
    }
}

#if DEBUG
#Preview("Replace saved Physical Keyboard") {
    ReplaceSavedPhysicalKeyboardPickerView(
        physicalKeyboard: KeyameleonPreviewFixtures.physicalKeyboard(
            name: "Keychron K2",
            assignment: nil
        ),
        candidates: [
            KeyameleonPreviewFixtures.physicalKeyboard(
                name: "HHKB Professional",
                id: "identity:preview.disconnected|anchor:serial:preview-disconnected",
                connection: .disconnected
            )
        ],
        onSelect: { _ in },
        onCancel: {}
    )
}

#Preview("Replace saved Physical Keyboard empty") {
    ReplaceSavedPhysicalKeyboardPickerView(
        physicalKeyboard: KeyameleonPreviewFixtures.physicalKeyboard(),
        candidates: [],
        onSelect: { _ in },
        onCancel: {}
    )
}
#endif
