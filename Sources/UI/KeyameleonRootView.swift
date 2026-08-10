import SwiftUI

@MainActor
struct KeyameleonRootView: View {
    @ObservedObject private var model: KeyameleonSetupModel
    @State private var assignmentPickerKeyboardID: PhysicalKeyboardRecordID?
    @State private var nameDrafts: [String: String] = [:]

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
                } else if model.guidedSetupStep == .assignments {
                    assignmentSetup
                } else {
                    permissionSetup
                }

                if model.showsAssignmentSetup {
                    configuration
                }
            }
            .padding(28)
        }
        .frame(minWidth: 460, minHeight: 280)
        .sheet(item: assignmentPickerBinding) { keyboard in
            KeyboardAssignmentPickerView(
                physicalKeyboard: keyboard,
                filteredInputSources: { query in
                    model.filteredInputSources(matching: query)
                },
                onSelect: { inputSource in
                    model.setKeyboardAssignment(
                        keyboard.id,
                        inputSourceIdentifier: inputSource.identifier
                    )
                    assignmentPickerKeyboardID = nil
                },
                onCancel: {
                    assignmentPickerKeyboardID = nil
                }
            )
        }
    }

    private var assignmentPickerBinding: Binding<PhysicalKeyboard?> {
        Binding(
            get: {
                guard let assignmentPickerKeyboardID else {
                    return nil
                }

                return model.physicalKeyboards.first { $0.id == assignmentPickerKeyboardID }
            },
            set: { keyboard in
                assignmentPickerKeyboardID = keyboard?.id
            }
        )
    }

    private var permissionSetup: some View {
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
                        ? KeyameleonAppMetadata.continueToAssignmentsButtonTitle
                        : KeyameleonAppMetadata.continueWithoutPermissionButtonTitle
                ) {
                    model.continueToAssignments()
                }
            }

            recoveryActions
        }
    }

    private var assignmentSetup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Name each Physical Keyboard and create Keyboard Assignments. Changes save immediately.")

            Text(KeyameleonAppMetadata.assignmentAppliesAfterActivation)
                .foregroundStyle(.secondary)

            switchingStatus

            HStack {
                Button(KeyameleonAppMetadata.finishWithoutAssignmentsButtonTitle) {
                    model.finishWithoutAssignments()
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

            if !model.isSetupComplete {
                Text(KeyameleonAppMetadata.assignmentAppliesAfterActivation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }

    private func physicalKeyboardRow(_ physicalKeyboard: PhysicalKeyboard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if physicalKeyboard.isAssignable {
                Text(KeyameleonAppMetadata.physicalKeyboardNameLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField(
                    physicalKeyboard.productName,
                    text: nameBinding(for: physicalKeyboard)
                )
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    commitName(for: physicalKeyboard)
                }
                .onChange(of: nameDrafts[physicalKeyboard.id.rawValue] ?? "") { _, newValue in
                    // Immediate save on edit; empty draft restores the product name.
                    model.setPhysicalKeyboardName(
                        physicalKeyboard.id,
                        customName: newValue
                    )
                }
            } else {
                Text(physicalKeyboard.name)
                    .font(.body.weight(.medium))
            }

            Text(
                physicalKeyboard.isBuiltIn
                    ? "Built-in"
                    : physicalKeyboard.transport.displayName
            )
            .foregroundStyle(.secondary)

            Text(assignmentStatusText(for: physicalKeyboard))
                .foregroundStyle(
                    physicalKeyboard.isAssignable ? Color.secondary : Color.orange
                )

            if physicalKeyboard.isAssignable {
                HStack {
                    Button(
                        physicalKeyboard.keyboardAssignment == nil
                            ? KeyameleonAppMetadata.assignButtonTitle
                            : KeyameleonAppMetadata.changeAssignmentButtonTitle
                    ) {
                        assignmentPickerKeyboardID = physicalKeyboard.id
                    }

                    if physicalKeyboard.keyboardAssignment != nil {
                        Button(KeyameleonAppMetadata.removeAssignmentButtonTitle) {
                            model.setKeyboardAssignment(
                                physicalKeyboard.id,
                                inputSourceIdentifier: nil
                            )
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(physicalKeyboard.name)
    }

    private func assignmentStatusText(for physicalKeyboard: PhysicalKeyboard) -> String {
        switch physicalKeyboard.assignmentState {
        case .unassigned:
            "Unassigned"
        case .assigned:
            if let name = model.assignmentDisplayName(for: physicalKeyboard) {
                "\(KeyameleonAppMetadata.keyboardAssignmentLabel): \(name)"
            } else {
                "Unavailable Keyboard Assignment"
            }
        case let .unsupported(reason):
            "Unsupported — \(reason.displayName)"
        }
    }

    private func nameBinding(for physicalKeyboard: PhysicalKeyboard) -> Binding<String> {
        Binding(
            get: {
                if let draft = nameDrafts[physicalKeyboard.id.rawValue] {
                    return draft
                }

                return physicalKeyboard.customName ?? physicalKeyboard.productName
            },
            set: { nameDrafts[physicalKeyboard.id.rawValue] = $0 }
        )
    }

    private func commitName(for physicalKeyboard: PhysicalKeyboard) {
        let draft = nameDrafts[physicalKeyboard.id.rawValue] ?? physicalKeyboard.name
        model.setPhysicalKeyboardName(physicalKeyboard.id, customName: draft)
    }
}

@MainActor
private struct KeyboardAssignmentPickerView: View {
    let physicalKeyboard: PhysicalKeyboard
    let filteredInputSources: (String) -> [EligibleInputSource]
    let onSelect: (EligibleInputSource) -> Void
    let onCancel: () -> Void

    @State private var query = ""

    private var visibleInputSources: [EligibleInputSource] {
        filteredInputSources(query)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(KeyameleonAppMetadata.assignmentPickerTitle)
                .font(.title2)

            Text(physicalKeyboard.name)
                .foregroundStyle(.secondary)

            Text(KeyameleonAppMetadata.assignmentAppliesAfterActivation)
                .font(.callout)
                .foregroundStyle(.secondary)

            TextField(KeyameleonAppMetadata.assignmentSearchPrompt, text: $query)
                .textFieldStyle(.roundedBorder)

            if visibleInputSources.isEmpty {
                Text("No eligible Input Sources found.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List(visibleInputSources) { inputSource in
                    Button {
                        onSelect(inputSource)
                    } label: {
                        Text(inputSource.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // Names only — never show technical Input Source identifiers.
                }
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 360, minHeight: 420)
    }
}
