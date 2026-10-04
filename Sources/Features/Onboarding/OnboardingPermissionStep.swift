import SwiftUI

@MainActor
struct OnboardingPermissionStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("Let Keyameleon recognise your keyboards.")
                .font(.title)
                .bold()
                .foregroundStyle(OnboardingPalette.primary)
            Text("Input Monitoring lets Keyameleon detect keyboard activity and select the assigned Input Source.")
                .font(.body)
                .lineSpacing(2)
                .padding(.vertical, 1)
                .foregroundStyle(OnboardingPalette.secondary)
            HStack(spacing: 20) {
                Image(systemName: "shield.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 34)
                    .foregroundStyle(OnboardingPalette.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Input Monitoring").font(.body).bold()
                    Text("Required for automatic switching")
                        .font(.callout)
                        .foregroundStyle(OnboardingPalette.secondary)
                }
                Spacer()
                Text("Required")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(OnboardingPalette.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(OnboardingPalette.chip, in: .capsule)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .background(OnboardingPalette.surface, in: .rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(OnboardingPalette.border) }
            VStack(alignment: .leading, spacing: 16) {
                OnboardingPermissionInstruction(number: 1, message: "Open the macOS permission prompt.")
                OnboardingPermissionInstruction(number: 2, message: "Enable Keyameleon in Input Monitoring.")
                OnboardingPermissionInstruction(number: 3, message: "Return here. Setup continues automatically.")
            }
            Text("Access can be changed later in System Settings.")
                .font(.callout)
                .foregroundStyle(OnboardingPalette.muted)
        }
    }
}

#if DEBUG
#Preview("Permission instructions") {
    OnboardingPermissionStep()
        .frame(width: 630)
}
#endif
