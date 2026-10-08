import SwiftUI

@MainActor
struct OnboardingFooter: View {
    let model: SetupModel

    var body: some View {
        HStack(spacing: 28) {
            switch model.guidedSetupStep {
            case .permission:
                // Denied means macOS already lists Keyameleon, so the person
                // only has to turn it on; unknown means macOS has to ask first.
                let isListed = model.activityTriggeredSwitching.outcome.hasAction(.openSystemSettings)
                Text(isListed ? "Already on? Restart to apply it." : "macOS will ask for permission.")
                    .font(.callout)
                    .foregroundStyle(OnboardingPalette.secondary)
                Spacer()
                if isListed {
                    Button("Restart \(AppIdentity.current.name)") { model.relaunch() }
                    Button("Open System Settings") { model.openSystemSettings() }
                        .buttonStyle(.borderedProminent)
                        .tint(OnboardingPalette.button)
                        .keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier("open-system-settings")
                } else {
                    Button("Allow Input Monitoring") { model.requestPermission() }
                        .buttonStyle(.borderedProminent)
                        .tint(OnboardingPalette.button)
                        .accessibilityIdentifier("request-permission")
                }
            case .assignments:
                Spacer()
                Button("Set Up Later") { model.continueToReady() }
                    .buttonStyle(.plain)
                    .foregroundStyle(OnboardingPalette.accent)
                    .disabled(model.hasPersistenceFailure)
                Button("Continue") { model.continueToReady() }
                    .buttonStyle(.borderedProminent)
                    .tint(OnboardingPalette.button)
                    .disabled(model.hasPersistenceFailure)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("continue-guided-setup")
            case .ready:
                Button("Back") { model.returnToAssignments() }
                Spacer()
                Button("Open Settings") { model.completeSetup(destination: .settings) }
                    .disabled(model.hasPersistenceFailure)
                Button("Finish") { model.completeSetup(destination: .menuBar) }
                    .buttonStyle(.borderedProminent)
                    .tint(OnboardingPalette.button)
                    .disabled(model.hasPersistenceFailure)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .font(.body.weight(.semibold))
        .controlSize(.large)
        .buttonBorderShape(.roundedRectangle(radius: 6))
        .padding(.horizontal, 37)
        .frame(minHeight: 67)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) { OnboardingPalette.border.frame(height: 1) }
    }
}

#if DEBUG
#Preview("Onboarding footer") {
    let fixture = PreviewFixtures.setup(.readyEmpty)
    OnboardingFooter(model: fixture.model)
        .frame(width: 705)
}
#endif
