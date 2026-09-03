import SwiftUI

@MainActor
struct KeyameleonKeyboardSettingsView: View {
    private let model: KeyameleonSetupModel
    private let contentPadding: CGFloat
    @State private var assignmentPickerKeyboardID: PhysicalKeyboardRecordID?
    @State private var replacePickerKeyboardID: PhysicalKeyboardRecordID?
    @State private var pendingReplaceConnectedID: PhysicalKeyboardRecordID?
    @State private var replaceTargetDisconnectedID: PhysicalKeyboardRecordID?
    @State private var forgetCandidateID: PhysicalKeyboardRecordID?
    @State private var nameDrafts: [String: String] = [:]
    @State private var designationNameDraft = ""

    init(
        model: KeyameleonSetupModel,
        contentPadding: CGFloat = 28
    ) {
        self.model = model
        self.contentPadding = contentPadding
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Physical Keyboards")
                    .font(.title3.weight(.semibold))

                Text("Name each keyboard and choose its assigned Input Source.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if let designationStatus = model.manualDesignationStatusText() {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(designationStatus)
                            .foregroundStyle(.secondary)
                        Button("Cancel Designation") {
                            model.cancelManualDesignation()
                        }
                    }
                    .settingsCardStyle()
                }

                if model.physicalKeyboards.isEmpty {
                    Text("No Physical Keyboards found.")
                        .foregroundStyle(.secondary)
                        .settingsCardStyle()
                } else {
                    VStack(spacing: 12) {
                        ForEach(model.physicalKeyboards) { physicalKeyboard in
                            physicalKeyboardCard(physicalKeyboard)
                        }
                    }
                }
            }
            .padding(contentPadding)
            .accessibilityIdentifier("physical-keyboard-configuration")
        }
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

    private func physicalKeyboardCard(_ physicalKeyboard: PhysicalKeyboard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(physicalKeyboard.isAssignable
                    ? "Physical Keyboard Name"
                    : physicalKeyboard.name)
                    .font(physicalKeyboard.isAssignable ? .caption : .body.weight(.medium))
                    .foregroundStyle(physicalKeyboard.isAssignable ? .secondary : .primary)

                Spacer()

                if physicalKeyboard.isActive {
                    Text("Active")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.tint.opacity(0.18), in: Capsule())
                }
            }

            if physicalKeyboard.isAssignable {
                TextField(
                    physicalKeyboard.productName,
                    text: nameBinding(for: physicalKeyboard)
                )
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Physical Keyboard Name for \(physicalKeyboard.name)")
                .onSubmit {
                    commitName(for: physicalKeyboard)
                }
                .onChange(of: nameDrafts[physicalKeyboard.id.rawValue] ?? "") { _, newValue in
                    model.setPhysicalKeyboardName(
                        physicalKeyboard.id,
                        customName: newValue
                    )
                }
            }

            Divider()

            HStack {
                Text(connectionDescription(for: physicalKeyboard))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(assignmentStatusText(for: physicalKeyboard))
                    .foregroundStyle(
                        physicalKeyboard.isAssignable ? Color.secondary : Color.orange
                    )
            }

            if physicalKeyboard.isAssignable {
                Divider()

                HStack {
                    Button(physicalKeyboard.keyboardAssignment == nil
                        ? "Assign…"
                        : "Change Assignment") {
                        assignmentPickerKeyboardID = physicalKeyboard.id
                    }

                    if physicalKeyboard.keyboardAssignment != nil {
                        Button("Remove Assignment") {
                            model.setKeyboardAssignment(
                                physicalKeyboard.id,
                                inputSourceIdentifier: nil
                            )
                        }
                    }

                    Spacer()

                    if physicalKeyboard.connectionState == .connected,
                       !model.replaceCandidates(for: physicalKeyboard.id).isEmpty {
                        Button("Replace…") {
                            pendingReplaceConnectedID = physicalKeyboard.id
                            replacePickerKeyboardID = physicalKeyboard.id
                        }
                    }

                    if model.canForgetPhysicalKeyboard(physicalKeyboard.id) {
                        Button("Forget…", role: .destructive) {
                            forgetCandidateID = physicalKeyboard.id
                        }
                    }
                }
            } else if model.canStartManualDesignation(for: physicalKeyboard.id) {
                Divider()
                Text(
                    "Save this external identity group only after it leaves, returns, and you confirm its name."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                Button("Manual Physical Keyboard Designation…") {
                    model.startManualDesignation(for: physicalKeyboard.id)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            physicalKeyboard.isActive
                ? Color.accentColor.opacity(0.12)
                : Color.primary.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(physicalKeyboard.name)
        .accessibilityValue(
            physicalKeyboard.isActive
                ? "Active · \(connectionDescription(for: physicalKeyboard))"
                : connectionDescription(for: physicalKeyboard)
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

    private func nameBinding(for physicalKeyboard: PhysicalKeyboard) -> Binding<String> {
        Binding(
            get: {
                nameDrafts[physicalKeyboard.id.rawValue]
                    ?? physicalKeyboard.customName
                    ?? physicalKeyboard.productName
            },
            set: { nameDrafts[physicalKeyboard.id.rawValue] = $0 }
        )
    }

    private func commitName(for physicalKeyboard: PhysicalKeyboard) {
        let draft = nameDrafts[physicalKeyboard.id.rawValue] ?? physicalKeyboard.name
        model.setPhysicalKeyboardName(physicalKeyboard.id, customName: draft)
    }

    private func connectionDescription(for physicalKeyboard: PhysicalKeyboard) -> String {
        let connection = switch physicalKeyboard.connectionState {
        case .connected: "Connected"
        case .disconnected: "Disconnected"
        }
        guard physicalKeyboard.connectionState == .connected else {
            return connection
        }

        let hardware = if physicalKeyboard.isBuiltIn {
            "Built-in"
        } else {
            switch physicalKeyboard.transport {
            case .usb: "USB"
            case .bluetooth: "Bluetooth"
            case .bluetoothLowEnergy: "Bluetooth Low Energy"
            case .other: "Other"
            }
        }
        return "\(connection) · \(hardware)"
    }

    private func assignmentStatusText(for physicalKeyboard: PhysicalKeyboard) -> String {
        switch physicalKeyboard.assignmentState {
        case .unassigned:
            "Unassigned"
        case .assigned:
            model.assignedInputSourceName(for: physicalKeyboard)
                .map { "Keyboard Assignment: \($0)" }
                ?? "Unavailable Keyboard Assignment"
        case let .unsupported(reason):
            "Unsupported — \(unsupportedReasonName(reason))"
        }
    }

    private func unsupportedReasonName(_ reason: PhysicalKeyboardUnsupportedReason) -> String {
        switch reason {
        case .missingIdentity: "Physical Keyboard Identity unavailable"
        case .unstableIdentity: "Physical Keyboard Identity unstable"
        case .sharedIdentity: "Physical Keyboard Identity shared"
        case .ambiguousIdentity: "Physical Keyboard Identity ambiguous"
        }
    }
}
