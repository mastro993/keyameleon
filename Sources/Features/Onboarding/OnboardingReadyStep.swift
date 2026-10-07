import SwiftUI

@MainActor
struct OnboardingReadyStep: View {
    let assignmentCount: Int
    let switchingStatus: SwitchingStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("You’re ready to switch.")
                .font(.title)
                .bold()
                .foregroundStyle(OnboardingPalette.primary)
            Text("Start typing on a keyboard. Keyameleon selects its assigned Input Source after it detects activity.")
                .font(.body)
                .lineSpacing(2)
                .padding(.vertical, 1)
                .foregroundStyle(OnboardingPalette.secondary)
            HStack(spacing: 10) {
                Image(systemName: assignmentCount > 0 ? "checkmark.circle.fill" : "info.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(assignmentCount > 0
                        ? OnboardingPalette.success : OnboardingPalette.muted)
                Text(assignmentCount == 0
                    ? "No Keyboard Assignments yet"
                    : "\(assignmentCount) Keyboard Assignment\(assignmentCount == 1 ? "" : "s") saved")
                    .foregroundStyle(assignmentCount > 0
                        ? OnboardingPalette.successText : OnboardingPalette.secondary)
            }
            .font(.body.weight(.semibold))
            if switchingStatus != .ready {
                Text(warning)
                    .font(.callout)
                    .foregroundStyle(OnboardingPalette.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(OnboardingPalette.surface, in: .rect(cornerRadius: 12))
            }
            Image("OnboardingMenu")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 631)
                .accessibilityLabel("Illustration showing Keyameleon in the menu bar")
            Text("Find Keyameleon in your menu bar.")
                .font(.body.weight(.semibold))
                .foregroundStyle(OnboardingPalette.primary)
        }
    }

    private var warning: String {
        switch switchingStatus {
        case .ready: ""
        case .permissionRequired:
            "Input Monitoring is off. Automatic switching will resume after you allow access in System Settings."
        case .paused:
            "Automatic switching is paused. Resume it from the menu bar when you are ready."
        case .temporarilyUnavailable:
            "Automatic switching is temporarily unavailable. Check the menu bar for recovery options."
        }
    }
}

#if DEBUG
#Preview("Ready content") {
    OnboardingReadyStep(assignmentCount: 2, switchingStatus: .ready)
        .frame(width: 631)
}
#endif
