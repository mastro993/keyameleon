import SwiftUI

@MainActor
struct OnboardingReadyStep: View {
    let assignmentCount: Int
    let switchingStatus: SwitchingStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(.readyTitle)
                .font(.title)
                .bold()
                .foregroundStyle(OnboardingPalette.primary)
            Text(.readyDescription)
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
                .accessibilityLabel(.readyMenuIllustration)
            Text(.readyFindInMenuBar)
                .font(.body.weight(.semibold))
                .foregroundStyle(OnboardingPalette.primary)
        }
    }

    private var summary: LocalizedStringResource {
        assignmentCount == 0 ? .readyNoKeyboardsAssigned : .readyKeyboardsAssigned(assignmentCount)
    }

    private var warning: LocalizedStringResource {
        switch switchingStatus {
        case .ready: ""
        case .permissionRequired: .readyWarningPermission
        case .paused: .readyWarningPaused
        case .temporarilyUnavailable: .readyWarningUnavailable
        }
    }
}

#if DEBUG
#Preview("Ready content") {
    OnboardingReadyStep(assignmentCount: 2, switchingStatus: .ready)
        .frame(width: 631)
}
#endif
