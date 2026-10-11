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
                Text(isListed ? .permissionAlreadyOn : .permissionWillAsk)
                    .font(.callout)
                    .foregroundStyle(OnboardingPalette.secondary)
                Spacer()
                if isListed {
                    Button(.restartApp(AppIdentity.current.name)) { model.relaunch() }
                    Button(.openSystemSettings) { model.openSystemSettings() }
                        .buttonStyle(.borderedProminent)
                        .tint(OnboardingPalette.button)
                        .keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier("open-system-settings")
                } else {
                    Button(.allowInputMonitoring) { model.requestPermission() }
                        .buttonStyle(.borderedProminent)
                        .tint(OnboardingPalette.button)
                        .accessibilityIdentifier("request-permission")
                }
            case .assignments:
                Spacer()
                Button(.setUpLater) { model.continueToReady() }
                    .buttonStyle(.plain)
                    .foregroundStyle(OnboardingPalette.accent)
                    .disabled(model.hasPersistenceFailure)
                Button(.continueSetup) { model.continueToReady() }
                    .buttonStyle(.borderedProminent)
                    .tint(OnboardingPalette.button)
                    .disabled(model.hasPersistenceFailure)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("continue-guided-setup")
            case .ready:
                Button(.back) { model.returnToAssignments() }
                Spacer()
                Button(.openSettings) { model.completeSetup(destination: .settings) }
                    .disabled(model.hasPersistenceFailure)
                Button(.finish) { model.completeSetup(destination: .menuBar) }
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
