import SwiftUI

/// The Input Source control of a Physical Keyboard row.
///
/// A grouped `Form` restyles a menu `Picker` into a borderless control sized
/// to its value, so rows with short and long Input Source names no longer line
/// up. A bordered `Menu` hosting the inline `Picker` keeps native selection
/// while the button fills one fixed column in every row.
@MainActor
struct InputSourceMenu: View {
    let title: String
    @Binding var selection: String?
    let inputSources: [EligibleInputSource]

    var body: some View {
        Menu {
            Picker(title, selection: $selection) {
                Text("Unassigned").tag(nil as String?)
                if let selection, unavailable {
                    Text("Unavailable").tag(Optional(selection)).disabled(true)
                }
                ForEach(inputSources) { source in
                    Text(source.name).tag(Optional(source.identifier))
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            Text(selectedName)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .buttonSizing(.flexible)
        .frame(width: 176)
        .accessibilityLabel(title)
        .accessibilityValue(selectedName)
        .help(selection != nil && unavailable
            ? "This input source is no longer in macOS. Choose another, or add it back in System Settings › Keyboard."
            : "")
    }

    private var unavailable: Bool {
        !inputSources.contains { $0.identifier == selection }
    }

    private var selectedName: String {
        guard let selection else { return "Unassigned" }
        return inputSources.first { $0.identifier == selection }?.name ?? "Unavailable"
    }
}

#if DEBUG
#Preview("Input Source menu") {
    @Previewable @State var selection: String?
    Form {
        InputSourceMenu(
            title: "Input Source",
            selection: $selection,
            inputSources: PreviewFixtures.inputSources()
        )
    }
    .formStyle(.grouped)
}
#endif
