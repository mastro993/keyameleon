import SwiftUI

/// A collapsed, read-only list of unsupported devices below the keyboard list,
/// shared by Guided setup and Settings.
///
/// Unsupported devices cannot take a Keyboard Assignment, so they stay out of
/// the main list. The section only explains what each device is and why it is
/// unsupported. Its title sits outside the grouped box as the section header,
/// and the whole header row toggles the devices.
@MainActor
struct UnsupportedPhysicalKeyboardsSection: View {
    let keyboards: [PhysicalKeyboard]

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if !keyboards.isEmpty {
            Section {
                if isExpanded {
                    ForEach(keyboards) { keyboard in
                        UnsupportedPhysicalKeyboardRow(keyboard: keyboard)
                            .listRowBackground(Theme.windowBackground)
                    }
                }
            } header: {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "chevron.right")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        Text("Unsupported devices (\(keyboards.count))")
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(Theme.secondary)
                        Spacer(minLength: 0)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .textCase(nil)
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
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
