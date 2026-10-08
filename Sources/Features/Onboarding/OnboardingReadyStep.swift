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
            Text("Type on an assigned keyboard and Keyameleon switches to its input source.")
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
                Text(summary)
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

    private var summary: LocalizedStringKey {
        assignmentCount == 0
            ? "No keyboards assigned yet"
            : "^[\(assignmentCount) keyboard](inflect: true) assigned"
    }

    private var warning: String {
        switch switchingStatus {
        case .ready: ""
        case .permissionRequired:
            "Input Monitoring is off. Turn it on in System Settings to start switching."
        case .paused:
            "Switching is paused. Resume it from the menu bar."
        case .temporarilyUnavailable:
            "Switching is temporarily unavailable and resumes automatically."
        }
    }
}

#if DEBUG
#Preview("Ready content") {
    OnboardingReadyStep(assignmentCount: 2, switchingStatus: .ready)
        .frame(width: 631)
}
#endif
