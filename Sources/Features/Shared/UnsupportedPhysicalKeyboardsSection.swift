import SwiftUI

/// A collapsed, read-only list of unsupported devices below the keyboard list,
/// shared by Guided setup and Settings.
///
/// Unsupported devices cannot take a Keyboard Assignment, so they stay out of
/// the main list. The section only explains what each device is and why it is
/// unsupported, inside a native collapsible section.
@MainActor
struct UnsupportedPhysicalKeyboardsSection: View {
    let keyboards: [PhysicalKeyboard]

    @State private var isExpanded = false

    var body: some View {
        if !keyboards.isEmpty {
            Section(isExpanded: $isExpanded) {
                ForEach(keyboards) { keyboard in
                    UnsupportedPhysicalKeyboardRow(keyboard: keyboard)
                }
            } header: {
                Text("Unsupported devices (\(keyboards.count))")
                    .help("Keyameleon can’t tell these devices apart reliably, so they can’t have an input source.")
                    .accessibilityIdentifier("unsupported-devices")
            }
        }
    }
}

#if DEBUG
#Preview("Unsupported devices") {
    Form {
        UnsupportedPhysicalKeyboardsSection(keyboards: [
            PreviewFixtures.unsupportedPhysicalKeyboard(),
            PreviewFixtures.unsupportedPhysicalKeyboard(name: "USB Receiver", reason: .sharedIdentity)
        ])
    }
    .formStyle(.grouped)
    .frame(width: 630, height: 320)
}
#endif
