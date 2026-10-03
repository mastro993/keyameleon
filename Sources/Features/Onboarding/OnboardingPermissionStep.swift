import SwiftUI

@MainActor
struct OnboardingPermissionStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Let Keyameleon recognise your keyboards.")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(OnboardingPalette.primary)
            Text("Input Monitoring lets Keyameleon detect keyboard activity and select the assigned Input Source.")
                .font(.title2)
                .foregroundStyle(OnboardingPalette.secondary)
            HStack(spacing: 16) {
                Image(systemName: "shield.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 34)
                    .foregroundStyle(OnboardingPalette.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Input Monitoring").font(.title2).bold()
                    Text("Required for automatic switching")
                        .font(.title3)
                        .foregroundStyle(OnboardingPalette.secondary)
                }
                Spacer()
                Text("Required")
                    .font(.title3)
                    .foregroundStyle(OnboardingPalette.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(OnboardingPalette.chip, in: .capsule)
            }
            .padding(20)
            .background(OnboardingPalette.surface, in: .rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(OnboardingPalette.border) }
            VStack(alignment: .leading, spacing: 17) {
                OnboardingPermissionInstruction(number: 1, message: "Open the macOS permission prompt.")
                OnboardingPermissionInstruction(number: 2, message: "Enable Keyameleon in Input Monitoring.")
                OnboardingPermissionInstruction(number: 3, message: "Return here. Setup continues automatically.")
            }
            .padding(.top, 12)
            Text("Access can be changed later in System Settings.")
                .font(.title2)
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
