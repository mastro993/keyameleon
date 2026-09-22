import SwiftUI

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

#if DEBUG
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
#endif
