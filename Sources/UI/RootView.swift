import SwiftUI

@MainActor
struct KeyameleonRootView: View {
    private let model: KeyameleonSetupModel
    private let switching: ActivityTriggeredSwitching

    init(
        model: KeyameleonSetupModel,
        switching: ActivityTriggeredSwitching
    ) {
        self.model = model
        self.switching = switching
    }

    var body: some View {
        Group {
            if model.isSetupComplete {
                VStack(spacing: 12) {
                    Text("Keyameleon")
                        .font(.title.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text("Guided setup is complete. Keyameleon stays in the menu bar.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("guided-setup")
            } else {
                ScrollView {
                    KeyameleonOnboardingView(model: model, switching: switching)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 520)
    }
}

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
struct KeyboardAssignmentPickerView: View {
    let physicalKeyboard: PhysicalKeyboard
    let filteredInputSources: (String) -> [EligibleInputSource]
    let onSelect: (EligibleInputSource) -> Void
    let onCancel: () -> Void

    @State private var query = ""

    private var visibleInputSources: [EligibleInputSource] {
        filteredInputSources(query)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose Input Source")
                .font(.title2)
                .accessibilityAddTraits(.isHeader)

            Text(physicalKeyboard.name)
                .foregroundStyle(.secondary)

            Text("Applies after next Activation Activity")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextField("Search Input Sources", text: $query)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Search Input Sources")

            if visibleInputSources.isEmpty {
                Text("No eligible Input Sources found.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List(visibleInputSources) { inputSource in
                    Button {
                        onSelect(inputSource)
                    } label: {
                        Text(inputSource.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(inputSource.name)
                    // Names only — never show technical Input Source identifiers.
                }
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 360, minHeight: 420)
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
#Preview("Guided setup complete") {
    let fixture = KeyameleonPreviewFixtures.setup(.completed)
    KeyameleonRootView(model: fixture.model, switching: fixture.switching)
}

#Preview("Permission required") {
    let fixture = KeyameleonPreviewFixtures.setup(.permissionRequired)
    KeyameleonRootView(model: fixture.model, switching: fixture.switching)
}

#Preview("Assignments populated") {
    let fixture = KeyameleonPreviewFixtures.setup(.assignmentsPopulated)
    KeyameleonRootView(model: fixture.model, switching: fixture.switching)
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .xxxLarge)
}

#Preview("Input Source picker") {
    KeyboardAssignmentPickerView(
        physicalKeyboard: KeyameleonPreviewFixtures.physicalKeyboard(),
        filteredInputSources: { query in
            KeyameleonPreviewFixtures.inputSources().filter {
                query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)
            }
        },
        onSelect: { _ in },
        onCancel: {}
    )
}

#Preview("Input Source picker empty") {
    KeyboardAssignmentPickerView(
        physicalKeyboard: KeyameleonPreviewFixtures.physicalKeyboard(name: "HHKB Professional"),
        filteredInputSources: { _ in [] },
        onSelect: { _ in },
        onCancel: {}
    )
}

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
