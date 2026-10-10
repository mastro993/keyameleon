import SwiftUI

/// The Input Source pop-up of a Physical Keyboard row.
///
/// An Unavailable Keyboard Assignment keeps its saved value and reads
/// `Unavailable`; it cannot be chosen again once another one is picked.
@MainActor
struct InputSourcePicker: View {
    let accessibilityLabel: String
    @Binding var selection: String?
    let inputSources: [EligibleInputSource]

    var body: some View {
        PopUpPicker(
            accessibilityLabel: accessibilityLabel,
            options: choices.map { PopUpPicker.Option(title: $0.title, isEnabled: $0.isEnabled) },
            selectedIndex: choices.firstIndex { $0.identifier == selection },
            onSelect: { selection = choices[$0].identifier }
        )
        .help(selection != nil && isUnavailable
            ? "This input source is no longer in macOS. Choose another, or add it back in System Settings › Keyboard."
            : "")
    }

    private struct Choice {
        let title: String
        let identifier: String?
        var isEnabled = true
    }

    private var choices: [Choice] {
        var choices = [Choice(title: "Unassigned", identifier: nil)]
        if let selection, isUnavailable {
            choices.append(Choice(title: "Unavailable", identifier: selection, isEnabled: false))
        }
        choices += inputSources.map { Choice(title: $0.name, identifier: $0.identifier) }
        return choices
    }

    private var isUnavailable: Bool {
        !inputSources.contains { $0.identifier == selection }
    }
}

#if DEBUG
#Preview("Input Source picker") {
    @Previewable @State var selection: String? = "com.apple.keylayout.Italian"
    Form {
        LabeledContent {
            InputSourcePicker(
                accessibilityLabel: "Input Source for Keychron K2",
                selection: $selection,
                inputSources: PreviewFixtures.inputSources()
            )
        } label: {
            Text("Keychron K2")
            Text("Connected")
        }
    }
    .formStyle(.grouped)
}
#endif
