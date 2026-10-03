import SwiftUI

@MainActor
struct OnboardingProgressStage: View {
    let number: Int
    let title: String
    let stage: GuidedSetupStep
    let current: GuidedSetupStep

    var body: some View {
        let active = stage.order <= current.order
        HStack(spacing: 9) {
            Text(number, format: .number)
                .font(.title3)
                .bold()
                .frame(width: 26, height: 26)
                .background(active ? OnboardingPalette.accent : OnboardingPalette.chip, in: .circle)
                .foregroundStyle(active ? .white : OnboardingPalette.muted)
            Text(title)
                .font(stage == current ? .title3.bold() : .title3)
                .foregroundStyle(stage == current ? OnboardingPalette.primary : OnboardingPalette.muted)
        }
    }
}

#if DEBUG
#Preview("Onboarding progress stage") {
    OnboardingProgressStage(number: 1, title: "Permissions", stage: .permission, current: .permission)
        .padding()
}
#endif
