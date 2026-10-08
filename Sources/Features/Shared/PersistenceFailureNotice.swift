import SwiftUI

@MainActor
struct PersistenceFailureNotice: View {
    let model: SetupModel

    var body: some View {
        if let message = model.persistenceError ?? model.activityTriggeredSwitching.persistenceError {
            VStack(alignment: .leading) {
                Text("Saved Physical Keyboards unavailable")
                    .font(.headline)
                Text(message)
                    .font(.callout)
                Button("Retry", action: model.retryPersistenceOperation)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("retry-keyboard-persistence")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
            .accessibilityIdentifier("keyboard-persistence-unavailable")
        }
    }
}

#if DEBUG
#Preview("Keyboard settings storage unavailable") {
    let session = SwiftDataPersistenceSession(openContainer: {
        throw CocoaError(.fileReadNoPermission)
    })
    let model = SetupModel(
        permissionProvider: PreviewListenPermissionProvider(state: .granted),
        setupStore: PreviewSetupDecisionStore(
            hasStartedGuidedSetup: true, hasCompletedGuidedSetup: true,
            guidedSetupStep: .assignments, isPaused: false
        ),
        inputMonitoringRecovery: PreviewInputMonitoringRecovery(),
        physicalKeyboardRecordStore: SwiftDataPhysicalKeyboardRecordStore(session: session),
        designationStore: SwiftDataManualPhysicalKeyboardDesignationStore(session: session)
    )
    KeyboardSettingsPane(model: model)
        .safeAreaInset(edge: .top) { PersistenceFailureNotice(model: model) }
        .frame(width: 620, height: 340)
}
#endif
