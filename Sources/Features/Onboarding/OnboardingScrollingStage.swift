import SwiftUI

@MainActor
struct OnboardingScrollingStage<Content: View>: View {
    let model: SetupModel
    let spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                PersistenceFailureNotice(model: model)
                OnboardingProgress(step: model.guidedSetupStep)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 37)
            .padding(.top, 34)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.automatic)
    }
}

#if DEBUG
#Preview("Onboarding scrolling stage") {
    let fixture = PreviewFixtures.setup(.permissionRequired)
    OnboardingScrollingStage(model: fixture.model, spacing: 28) {
        OnboardingPermissionStep(isListed: false)
    }
    .environment(fixture.model)
    .frame(width: 705)
    .background(OnboardingPalette.background)
}
#endif
