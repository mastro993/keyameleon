import SwiftUI

@MainActor
struct OnboardingProgressConnector: View {
    let width: CGFloat

    var body: some View {
        OnboardingPalette.border
            .frame(width: width)
            .frame(height: 1)
    }
}

#if DEBUG
#Preview("Onboarding progress connector") {
    OnboardingProgressConnector(width: 44)
        .frame(width: 44)
}
#endif
