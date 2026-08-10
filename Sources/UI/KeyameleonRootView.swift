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

                configuration
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

    private var configuration: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Physical Keyboards")
                .font(.headline)

            if model.physicalKeyboards.isEmpty {
                Text("No Physical Keyboards found.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(model.physicalKeyboards) { physicalKeyboard in
                        physicalKeyboardRow(physicalKeyboard)
                    }
                }
            }

            Text("Input Sources")
                .font(.headline)

            if model.eligibleInputSources.isEmpty {
                Text("No eligible Input Sources found.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(model.eligibleInputSources) { inputSource in
                        Text(inputSource.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private func physicalKeyboardRow(_ physicalKeyboard: PhysicalKeyboard) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(physicalKeyboard.name)
                .font(.body.weight(.medium))

            Text(
                physicalKeyboard.isBuiltIn
                    ? "Built-in"
                    : physicalKeyboard.transport.displayName
            )
            .foregroundStyle(.secondary)

            Text(physicalKeyboard.statusDescription)
                .foregroundStyle(
                    physicalKeyboard.isAssignable ? Color.secondary : Color.orange
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(physicalKeyboard.name)
        .accessibilityValue(
            "\(physicalKeyboard.isBuiltIn ? "Built-in" : physicalKeyboard.transport.displayName), \(physicalKeyboard.statusDescription)"
        )
    }
}
