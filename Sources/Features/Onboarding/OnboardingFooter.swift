import SwiftUI

@MainActor
struct OnboardingFooter: View {
    let model: KeyameleonSetupModel

    var body: some View {
        HStack(spacing: 12) {
            switch model.guidedSetupStep {
            case .permission:
                Text(model.isWaitingForListenPermission
                    ? "Waiting for Input Monitoring permission."
                    : "macOS will ask for permission.")
                    .font(.title3)
                    .foregroundStyle(OnboardingPalette.secondary)
                Spacer()
                if model.isWaitingForListenPermission {
                    Button("Open System Settings") { model.openSystemSettings() }
                    Button("Check Again") { model.checkPermissionAgain() }
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
                    .disabled(hasPersistenceFailure)
                Button("Continue") { model.continueToReady() }
                    .buttonStyle(.borderedProminent)
                    .tint(OnboardingPalette.button)
                    .disabled(hasPersistenceFailure)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("continue-guided-setup")
            case .ready:
                Button("Back") { model.returnToAssignments() }
                Spacer()
                Button("Open Settings") { model.completeSetup(destination: .settings) }
                    .disabled(hasPersistenceFailure)
                Button("Finish") { model.completeSetup(destination: .menuBar) }
                    .buttonStyle(.borderedProminent)
                    .tint(OnboardingPalette.button)
                    .disabled(hasPersistenceFailure)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .controlSize(.large)
        .buttonBorderShape(.roundedRectangle(radius: 6))
        .padding(.horizontal, 37)
        .frame(height: 67)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) { OnboardingPalette.border.frame(height: 1) }
    }

    private var hasPersistenceFailure: Bool {
        model.persistenceError != nil || model.activityTriggeredSwitching.persistenceError != nil
    }
}

#if DEBUG
#Preview("Onboarding footer") {
    let fixture = KeyameleonPreviewFixtures.setup(.readyEmpty)
    OnboardingFooter(model: fixture.model)
        .frame(width: 705)
}
#endif
