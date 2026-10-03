import SwiftUI

@MainActor
struct OnboardingProgress: View {
    let step: GuidedSetupStep

    var body: some View {
        HStack(spacing: 12) {
            OnboardingProgressStage(number: 1, title: "Permissions", stage: .permission, current: step)
            OnboardingProgressConnector()
            OnboardingProgressStage(number: 2, title: "Keyboards", stage: .assignments, current: step)
            OnboardingProgressConnector()
            OnboardingProgressStage(number: 3, title: "Ready", stage: .ready, current: step)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Setup progress: \(step.label)")
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

    var label: String {
        switch self {
        case .permission: "Permissions"
        case .assignments: "Keyboards"
        case .ready: "Ready"
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
