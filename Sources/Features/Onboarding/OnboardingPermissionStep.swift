import SwiftUI

@MainActor
struct OnboardingPermissionStep: View {
    /// Whether macOS already lists Keyameleon in Input Monitoring, so the
    /// footer offers Open System Settings instead of Allow Input Monitoring.
    let isListed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("Let Keyameleon recognize your keyboards.")
                .font(.title)
                .bold()
                .foregroundStyle(OnboardingPalette.primary)
            HStack(spacing: 20) {
                Image(systemName: "shield.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 34)
                    .foregroundStyle(OnboardingPalette.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Input Monitoring").font(.body).bold()
                    Text("Tells Keyameleon which keyboard you’re typing on")
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
                OnboardingPermissionInstruction(
                    number: 1,
                    message: isListed
                        ? "Click Open System Settings."
                        : "Click Allow Input Monitoring, then Open System Settings."
                )
                OnboardingPermissionInstruction(
                    number: 2,
                    message: "Turn on \(AppIdentity.current.name) in Input Monitoring."
                )
                OnboardingPermissionInstruction(
                    number: 3,
                    message: "If asked, click Quit & Reopen. Setup continues automatically."
                )
            }
        }
    }
}

#if DEBUG
#Preview("Permission instructions") {
    OnboardingPermissionStep(isListed: false)
        .frame(width: 630)
}

#Preview("Permission instructions after macOS asked") {
    OnboardingPermissionStep(isListed: true)
        .frame(width: 630)
}
#endif
