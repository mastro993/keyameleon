import SwiftUI

@MainActor
struct KeyameleonKeyboardSettingsView: View {
    private let model: KeyameleonSetupModel
    @State private var assignmentPickerKeyboardID: PhysicalKeyboardRecordID?
    @State private var replacePickerKeyboardID: PhysicalKeyboardRecordID?
    @State private var pendingReplaceConnectedID: PhysicalKeyboardRecordID?
    @State private var replaceTargetDisconnectedID: PhysicalKeyboardRecordID?
    @State private var forgetCandidateID: PhysicalKeyboardRecordID?
    @State private var excludeCandidateID: PhysicalKeyboardRecordID?
    @State private var renameCandidateID: PhysicalKeyboardRecordID?
    @State private var renameDraft = ""
    @State private var designationNameDraft = ""

    init(model: KeyameleonSetupModel) {
        self.model = model
    }

    var body: some View {
        Group {
            if model.physicalKeyboards.isEmpty, model.excludedPhysicalKeyboards.isEmpty {
                ContentUnavailableView {
                    Label("No Physical Keyboards", systemImage: "keyboard")
                } description: {
                    Text("Connect a Physical Keyboard to register it with Keyameleon.")
                }
            } else {
                List {
                    if let designationStatus = model.manualDesignationStatusText() {
                        Section {
                            HStack(spacing: 12) {
                                Text(designationStatus)
                                Spacer(minLength: 12)
                                Button("Cancel Designation", action: model.cancelManualDesignation)
                            }
                        }
                    }

                    Section {
                        ForEach(model.physicalKeyboards) { physicalKeyboard in
                            KeyboardSettingsRowView(
                                row: makeRow(for: physicalKeyboard),
                                actions: makeActions(for: physicalKeyboard)
                            )
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        }
                    }

                    if !model.excludedPhysicalKeyboards.isEmpty {
                        Section {
                            ForEach(model.excludedPhysicalKeyboards, id: \.key) { exclusion in
                                HStack(spacing: 12) {
                                    Image(systemName: "keyboard.badge.ellipsis")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                        .accessibilityHidden(true)
                                    Text(exclusion.name)
                                        .font(.headline)
                                    Spacer(minLength: 16)
                                    Button("Include Again") {
                                        model.restorePhysicalKeyboard(exclusionKey: exclusion.key)
                                    }
                                    .buttonStyle(.bordered)
                                    .accessibilityIdentifier("include-excluded-device-again")
                                    .accessibilityLabel("Include \(exclusion.name) again")
                                }
                                .keyameleonCard()
                                .listRowSeparator(.hidden)
                                .listRowInsets(
                                    EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
                                )
                            }
                        } header: {
                            Text("Excluded Devices")
                        } footer: {
                            Text("Keyameleon does not treat these devices as Physical Keyboards.")
                                .font(.callout)
                        }
                        .accessibilityIdentifier("excluded-devices")
                    }
                }
                .listStyle(.inset)
            }
        }
        .accessibilityIdentifier("physical-keyboard-configuration")
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
        .sheet(item: replacePickerBinding) { keyboard in
            ReplaceSavedPhysicalKeyboardPickerView(
                physicalKeyboard: keyboard,
                candidates: model.replaceCandidates(for: keyboard.id),
                onSelect: { candidate in
                    replacePickerKeyboardID = nil
                    replaceTargetDisconnectedID = candidate.id
                },
                onCancel: {
                    replacePickerKeyboardID = nil
                    pendingReplaceConnectedID = nil
                }
            )
        }
        .sheet(item: renameCandidateBinding) { keyboard in
            PhysicalKeyboardNameSheet(
                nameDraft: $renameDraft,
                productName: keyboard.productName,
                onSave: {
                    model.setPhysicalKeyboardName(keyboard.id, customName: renameDraft)
                    renameCandidateID = nil
                },
                onCancel: {
                    renameCandidateID = nil
                }
            )
        }
        .confirmationDialog(
            "Forget Physical Keyboard?",
            isPresented: forgetConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Forget", role: .destructive) {
                if let forgetCandidateID {
                    model.forgetPhysicalKeyboard(forgetCandidateID)
                }
                forgetCandidateID = nil
            }
            Button("Cancel", role: .cancel) {
                forgetCandidateID = nil
            }
        } message: {
            if let forgetCandidateID {
                Text(model.forgetConfirmationMessage(for: forgetCandidateID))
            }
        }
        .confirmationDialog(
            "Not a Physical Keyboard?",
            isPresented: excludeConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Exclude") {
                if let excludeCandidateID {
                    model.excludePhysicalKeyboard(excludeCandidateID)
                }
                excludeCandidateID = nil
            }
            Button("Cancel", role: .cancel) {
                excludeCandidateID = nil
            }
        } message: {
            if let excludeCandidateID {
                Text(model.exclusionConfirmationMessage(for: excludeCandidateID))
            }
        }
        .confirmationDialog(
            "Replace Saved Physical Keyboard?",
            isPresented: replaceConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Replace", role: .destructive) {
                if let pendingReplaceConnectedID,
                   let replaceTargetDisconnectedID {
                    model.replaceSavedPhysicalKeyboard(
                        replaceTargetDisconnectedID,
                        with: pendingReplaceConnectedID
                    )
                }
                replaceTargetDisconnectedID = nil
                pendingReplaceConnectedID = nil
            }
            Button("Cancel", role: .cancel) {
                replaceTargetDisconnectedID = nil
                pendingReplaceConnectedID = nil
            }
        } message: {
            if let pendingReplaceConnectedID,
               let replaceTargetDisconnectedID {
                Text(
                    model.replaceConfirmationMessage(
                        replacing: replaceTargetDisconnectedID,
                        with: pendingReplaceConnectedID
                    )
                )
            }
        }
        .sheet(isPresented: designationNameConfirmationPresented) {
            ManualPhysicalKeyboardDesignationNameSheet(
                nameDraft: $designationNameDraft,
                onConfirm: {
                    model.confirmManualDesignationName(designationNameDraft)
                    designationNameDraft = ""
                },
                onCancel: {
                    model.cancelManualDesignation()
                    designationNameDraft = ""
                }
            )
            .onAppear {
                if case let .awaitingNameConfirmation(_, productName) = model.manualDesignationPhase {
                    designationNameDraft = productName
                }
            }
        }
    }

    private func makeRow(for physicalKeyboard: PhysicalKeyboard) -> KeyboardSettingsRow {
        KeyboardSettingsRow(
            physicalKeyboard: physicalKeyboard,
            assignedInputSourceName: model.assignedInputSourceName(for: physicalKeyboard),
            canReplace: !model.replaceCandidates(for: physicalKeyboard.id).isEmpty,
            canForget: model.canForgetPhysicalKeyboard(physicalKeyboard.id),
            canExclude: model.canExcludePhysicalKeyboard(physicalKeyboard.id),
            canStartManualDesignation: model.canStartManualDesignation(for: physicalKeyboard.id)
        )
    }

    private func makeActions(for physicalKeyboard: PhysicalKeyboard) -> KeyboardSettingsRowActions {
        KeyboardSettingsRowActions(
            chooseInputSource: {
                assignmentPickerKeyboardID = physicalKeyboard.id
            },
            removeAssignment: {
                model.setKeyboardAssignment(physicalKeyboard.id, inputSourceIdentifier: nil)
            },
            rename: {
                renameDraft = physicalKeyboard.name
                renameCandidateID = physicalKeyboard.id
            },
            replace: {
                pendingReplaceConnectedID = physicalKeyboard.id
                replacePickerKeyboardID = physicalKeyboard.id
            },
            forget: {
                forgetCandidateID = physicalKeyboard.id
            },
            exclude: {
                excludeCandidateID = physicalKeyboard.id
            },
            startManualDesignation: {
                model.startManualDesignation(for: physicalKeyboard.id)
            }
        )
    }

    private var renameCandidateBinding: Binding<PhysicalKeyboard?> {
        Binding(
            get: {
                guard let renameCandidateID else {
                    return nil
                }
                return model.physicalKeyboards.first { $0.id == renameCandidateID }
            },
            set: { keyboard in
                renameCandidateID = keyboard?.id
            }
        )
    }

    private var designationNameConfirmationPresented: Binding<Bool> {
        Binding(
            get: {
                if case .awaitingNameConfirmation = model.manualDesignationPhase {
                    return true
                }
                return false
            },
            set: { isPresented in
                if !isPresented, case .awaitingNameConfirmation = model.manualDesignationPhase {
                    model.cancelManualDesignation()
                    designationNameDraft = ""
                }
            }
        )
    }

    private var forgetConfirmationPresented: Binding<Bool> {
        Binding(
            get: { forgetCandidateID != nil },
            set: { isPresented in
                if !isPresented {
                    forgetCandidateID = nil
                }
            }
        )
    }

    private var excludeConfirmationPresented: Binding<Bool> {
        Binding(
            get: { excludeCandidateID != nil },
            set: { isPresented in
                if !isPresented {
                    excludeCandidateID = nil
                }
            }
        )
    }

    private var replaceConfirmationPresented: Binding<Bool> {
        Binding(
            get: { replaceTargetDisconnectedID != nil },
            set: { isPresented in
                if !isPresented {
                    replaceTargetDisconnectedID = nil
                    pendingReplaceConnectedID = nil
                }
            }
        )
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

    private var replacePickerBinding: Binding<PhysicalKeyboard?> {
        Binding(
            get: {
                guard let replacePickerKeyboardID else {
                    return nil
                }
                return model.physicalKeyboards.first { $0.id == replacePickerKeyboardID }
            },
            set: { keyboard in
                replacePickerKeyboardID = keyboard?.id
            }
        )
    }
}

#if DEBUG
#Preview("Keyboard settings empty") {
    let fixture = KeyameleonPreviewFixtures.setup(.assignmentsEmpty)
    KeyameleonKeyboardSettingsView(model: fixture.model)
}

#Preview("Keyboard settings populated") {
    let fixture = KeyameleonPreviewFixtures.setup(.assignmentsPopulated)
    KeyameleonKeyboardSettingsView(model: fixture.model)
        .preferredColorScheme(.dark)
}

#Preview("Keyboard settings mixed states") {
    let fixture = KeyameleonPreviewFixtures.setup(.mixedAssignments)
    KeyameleonKeyboardSettingsView(model: fixture.model)
        .environment(\.dynamicTypeSize, .xxxLarge)
}

#Preview("Keyboard settings designation") {
    let fixture = KeyameleonPreviewFixtures.setup(.designationInProgress)
    KeyameleonKeyboardSettingsView(model: fixture.model)
}

#Preview("Keyboard settings excluded devices") {
    let fixture = KeyameleonPreviewFixtures.setup(.excludedDevices)
    KeyameleonKeyboardSettingsView(model: fixture.model)
}
#endif
