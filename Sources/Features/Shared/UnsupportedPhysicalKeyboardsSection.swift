import SwiftUI

/// A collapsed, read-only list of unsupported devices below the keyboard list,
/// shared by Guided setup and Settings.
///
/// Unsupported devices cannot take a Keyboard Assignment, so they stay out of
/// the main list. The section only explains what each device is and why it is
/// unsupported.
@MainActor
struct UnsupportedPhysicalKeyboardsSection: View {
    let keyboards: [PhysicalKeyboard]

    @State private var isExpanded = false

    var body: some View {
        if !keyboards.isEmpty {
            Section {
                DisclosureGroup(isExpanded: $isExpanded) {
                    VStack(alignment: .leading) {
                        Text(
                            "Keyameleon can’t recognize these devices reliably, "
                                + "so they can’t have a Keyboard Assignment. "
                                + "Some aren’t keyboards, such as a mouse or headset with buttons."
                        )
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(keyboards) { keyboard in
                            Divider()
                            UnsupportedPhysicalKeyboardRow(keyboard: keyboard)
                        }
                    }
                    .padding(.vertical)
                } label: {
                    Text("Unsupported devices (\(keyboards.count))")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(Theme.secondary)
                }
                .accessibilityIdentifier("unsupported-devices")
            }
            .listRowBackground(Theme.windowBackground)
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
