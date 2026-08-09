import SwiftUI

@MainActor
struct KeyameleonRootView: View {
    @ObservedObject private var model: KeyameleonSetupModel

    init(model: KeyameleonSetupModel) {
        _model = ObservedObject(wrappedValue: model)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(model.isSetupComplete ? KeyameleonAppMetadata.displayName : KeyameleonAppMetadata.guidedSetupTitle)
                    .font(.title)
                    .accessibilityAddTraits(.isHeader)

                if model.isSetupComplete {
                    completedSetup
                } else {
                    guidedSetup
                }
            }
            .padding(28)
        }
        .frame(minWidth: 460, minHeight: 280)
    }

    private var guidedSetup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity-Triggered Switching keeps each Physical Keyboard aligned with its assigned Input Source after Keyameleon observes Activation Activity.")

            Text("Keyameleon does not provide a First-Key Guarantee. Your normal input remains available, and macOS can process events before Input Source verification finishes.")

            Text("Key Content stays inside observation and classification. Keyameleon does not save or export Key Content.")

            Text("Keyameleon needs Input Monitoring permission to observe Activation Activity from each Physical Keyboard. Request Permission opens macOS's permission flow.")

            switchingStatus

            HStack {
                Button(KeyameleonAppMetadata.requestPermissionButtonTitle) {
                    model.requestPermission()
                }
                .disabled(model.switchingStatus == .ready)

                Button(
                    model.switchingStatus == .ready
                        ? KeyameleonAppMetadata.finishSetupButtonTitle
                        : KeyameleonAppMetadata.continueWithoutPermissionButtonTitle
                ) {
                    model.completeSetup()
                }
            }

            recoveryActions
        }
    }

    private var completedSetup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Guided setup is complete. Keyameleon remains in Menu first mode.")
                .foregroundStyle(.secondary)

            switchingStatus

            Text(
                model.switchingStatus == .ready
                    ? "Activity-Triggered Switching can observe Activation Activity."
                    : "Physical Keyboard observation and Input Source requests remain stopped until listen permission is available."
            )

            recoveryActions
        }
    }

    private var switchingStatus: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Switching Status")
                .font(.headline)
            Text(model.switchingStatus.displayName)
                .font(.title3)
                .accessibilityValue(model.switchingStatus.displayName)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    private var recoveryActions: some View {
        HStack {
            Button(KeyameleonAppMetadata.openSystemSettingsMenuItemTitle) {
                model.openSystemSettings()
            }

            Button(KeyameleonAppMetadata.checkAgainMenuItemTitle) {
                model.refreshPermission()
            }
        }
    }
}
