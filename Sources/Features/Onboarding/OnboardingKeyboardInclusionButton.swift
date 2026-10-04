import SwiftUI

@MainActor
struct OnboardingKeyboardInclusionButton: View {
    let isIncluded: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Include keyboard", systemImage: isIncluded ? "eye" : "eye.slash")
                .labelStyle(.iconOnly)
                .font(.title3)
                .foregroundStyle(OnboardingPalette.secondary)
                .frame(width: 28, height: 28)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(isIncluded ? "Not a keyboard? Turn off." : "Include keyboard")
        .disabled(isDisabled)
        .accessibilityLabel("Include keyboard")
        .accessibilityIdentifier(isIncluded ? "not-a-keyboard" : "include-excluded-device-again")
        .accessibilityRepresentation {
            Toggle("Include keyboard", isOn: Binding(
                get: { isIncluded },
                set: { if $0 != isIncluded { action() } }
            ))
            .disabled(isDisabled)
            .accessibilityIdentifier(isIncluded ? "not-a-keyboard" : "include-excluded-device-again")
        }
    }
}

#if DEBUG
#Preview("Keyboard inclusion") {
    @Previewable @State var isIncluded = true
    OnboardingKeyboardInclusionButton(isIncluded: isIncluded, isDisabled: false) {
        isIncluded.toggle()
    }
    .padding()
}
#endif
