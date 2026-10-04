import SwiftUI

@MainActor
struct OnboardingPermissionInstruction: View {
    let number: Int
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number, format: .number)
                .font(.body.weight(.semibold))
                .foregroundStyle(OnboardingPalette.muted)
                .frame(width: 22, height: 22)
                .background(OnboardingPalette.chip, in: .circle)
            Text(message)
                .font(.body)
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
