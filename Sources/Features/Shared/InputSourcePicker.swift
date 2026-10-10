import SwiftUI

/// The native Input Source picker of a Physical Keyboard row.
///
/// The row label (name and connection status) is the picker's own label, so
/// a grouped `Form` lays it out like System Settings. An Unavailable Keyboard
/// Assignment keeps its saved value and reads `Unavailable`.
@MainActor
struct InputSourcePicker<Label: View>: View {
    @Binding var selection: String?
    let inputSources: [EligibleInputSource]
    @ViewBuilder let label: Label

    var body: some View {
        Picker(selection: $selection) {
            Text("Unassigned").tag(nil as String?)
            if let selection, isUnavailable {
                Text("Unavailable").tag(Optional(selection)).disabled(true)
            }
            ForEach(inputSources) { source in
                Text(source.name).tag(Optional(source.identifier))
            }
        } label: {
            label
        }
        .help(selection != nil && isUnavailable
            ? "This input source is no longer in macOS. Choose another, or add it back in System Settings › Keyboard."
            : "")
    }

    private var isUnavailable: Bool {
        !inputSources.contains { $0.identifier == selection }
    }
}

#if DEBUG
#Preview("Input Source picker") {
    @Previewable @State var selection: String? = "com.apple.keylayout.Italian"
    Form {
        InputSourcePicker(selection: $selection, inputSources: PreviewFixtures.inputSources()) {
            Text("Keychron K2")
            Text("Connected")
        }
    }
    .formStyle(.grouped)
}
#endif
