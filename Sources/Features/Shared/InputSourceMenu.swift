import SwiftUI

/// The Input Source control of a Physical Keyboard or App Assignment row.
///
/// A `PopUpPicker` keeps the System Settings pop-up box visible and fills one
/// fixed column, so rows with short and long Input Source names line up.
@MainActor
struct InputSourceMenu: View {
    let title: String
    @Binding var selection: String?
    let inputSources: [EligibleInputSource]
    /// An App Assignment always has an Input Source; removing it is a separate action.
    var allowsUnassigned = true

    var body: some View {
        PopUpPicker(
            accessibilityLabel: title,
            options: choices.map { PopUpPicker.Option(title: $0.title, isEnabled: $0.isEnabled) },
            selectedIndex: choices.firstIndex { $0.identifier == selection },
            onSelect: { selection = choices[$0].identifier }
        )
        .frame(width: 176)
        .help(selection != nil && unavailable ? String(localized: .inputSourceRemovedHelp) : "")
    }

    private struct Choice {
        let title: String
        let identifier: String?
        var isEnabled = true
    }

    private var choices: [Choice] {
        var choices = allowsUnassigned
            ? [Choice(title: String(localized: .inputSourceUnassigned), identifier: nil)]
            : []
        if let selection, unavailable {
            choices.append(Choice(
                title: String(localized: .inputSourceUnavailable),
                identifier: selection,
                isEnabled: false
            ))
        }
        choices += inputSources.map { Choice(title: $0.name, identifier: $0.identifier) }
        return choices
    }

    private var unavailable: Bool {
        !inputSources.contains { $0.identifier == selection }
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
