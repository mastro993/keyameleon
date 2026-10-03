import SwiftUI

@MainActor
struct OnboardingProgressConnector: View {
    var body: some View {
        OnboardingPalette.border
            .frame(minWidth: 8, maxWidth: 40)
            .frame(height: 1)
    }
}

#if DEBUG
#Preview("Onboarding progress connector") {
    OnboardingProgressConnector()
        .frame(width: 40)
}
#endif
