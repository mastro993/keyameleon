import SwiftUI

@MainActor
struct OnboardingPermissionInstruction: View {
    let number: Int
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number, format: .number)
                .font(.title3)
                .bold()
                .foregroundStyle(OnboardingPalette.muted)
                .frame(width: 25, height: 25)
                .background(OnboardingPalette.chip, in: .circle)
            Text(message)
                .font(.title2)
                .foregroundStyle(OnboardingPalette.primary)
                .padding(.top, 3)
        }
    }
}

#if DEBUG
#Preview("Permission instruction") {
    OnboardingPermissionInstruction(number: 1, message: "Open the macOS permission prompt.")
        .padding()
}
#endif
