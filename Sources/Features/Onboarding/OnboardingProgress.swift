import SwiftUI

@MainActor
struct OnboardingProgress: View {
    let step: GuidedSetupStep

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 34) {
                OnboardingProgressStage(number: 1, stage: .permission, current: step)
                OnboardingProgressConnector(width: 44)
                OnboardingProgressStage(number: 2, stage: .assignments, current: step)
                OnboardingProgressConnector(width: 44)
                OnboardingProgressStage(number: 3, stage: .ready, current: step)
            }
            HStack(spacing: 12) {
                OnboardingProgressStage(number: 1, stage: .permission, current: step)
                OnboardingProgressConnector(width: 8)
                OnboardingProgressStage(number: 2, stage: .assignments, current: step)
                OnboardingProgressConnector(width: 8)
                OnboardingProgressStage(number: 3, stage: .ready, current: step)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(.setupProgress(String(localized: step.label)))
    }

}

extension GuidedSetupStep {
    var order: Int {
        switch self {
        case .permission: 1
        case .assignments: 2
        case .ready: 3
        }
    }

    var label: LocalizedStringResource {
        switch self {
        case .permission: .setupStepPermissions
        case .assignments: .keyboards
        case .ready: .setupStepReady
        }
    }
}

#if DEBUG
#Preview("Onboarding progress") {
    OnboardingProgress(step: .assignments)
        .frame(width: 471)
        .padding()
        .background(OnboardingPalette.background)
}
#endif
