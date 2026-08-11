import SwiftUI

@MainActor
struct KeyameleonRootView: View {
    @ObservedObject private var model: KeyameleonSetupModel
    @ObservedObject private var diagnosticModel: KeyameleonGeneralSettingsModel
    @State private var assignmentPickerKeyboardID: PhysicalKeyboardRecordID?
    @State private var replacePickerKeyboardID: PhysicalKeyboardRecordID?
    @State private var pendingReplaceConnectedID: PhysicalKeyboardRecordID?
    @State private var replaceTargetDisconnectedID: PhysicalKeyboardRecordID?
    @State private var forgetCandidateID: PhysicalKeyboardRecordID?
    @State private var nameDrafts: [String: String] = [:]
    @State private var designationNameDraft = ""

    init(
        model: KeyameleonSetupModel,
        diagnosticModel: KeyameleonGeneralSettingsModel
    ) {
        _model = ObservedObject(wrappedValue: model)
        _diagnosticModel = ObservedObject(wrappedValue: diagnosticModel)
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

                if model.shouldOfferOperationalNotificationSetup {
                    operationalNotificationSetup
                }
                KeyameleonDiagnosticBundleReviewView(model: diagnosticModel)
            }
            .padding(28)
            .accessibilityIdentifier(KeyameleonAppMetadata.guidedSetupAccessibilityIdentifier)
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
            KeyameleonAppMetadata.forgetConfirmationTitle,
            isPresented: forgetConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(KeyameleonAppMetadata.confirmForgetButtonTitle, role: .destructive) {
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
            KeyameleonAppMetadata.replaceConfirmationTitle,
            isPresented: replaceConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(KeyameleonAppMetadata.confirmReplaceButtonTitle, role: .destructive) {
                if let pendingReplaceConnectedID,
                   let replaceTargetDisconnectedID
                {
                    model.replaceSavedPhysicalKeyboard(
                        replaceTargetDisconnectedID,
                        with: pendingReplaceConnectedID
                    )
                }
                self.replaceTargetDisconnectedID = nil
                self.pendingReplaceConnectedID = nil
            }
            Button("Cancel", role: .cancel) {
                replaceTargetDisconnectedID = nil
                pendingReplaceConnectedID = nil
            }
        } message: {
            if let pendingReplaceConnectedID,
               let replaceTargetDisconnectedID
            {
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

    private var permissionSetup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity-Triggered Switching keeps each Physical Keyboard aligned with its assigned Input Source after Keyameleon observes Activation Activity.")

            Text("Keyameleon does not provide a First-Key Guarantee. Your normal input remains available, and macOS can process events before Input Source verification finishes.")

            Text("Key Content stays inside observation and classification. Keyameleon does not save or export Key Content.")

            Text("Keyameleon needs Input Monitoring permission to observe Activation Activity from each Physical Keyboard. Request Permission opens macOS's permission flow.")

            switchingStatus

            if model.switchingStatus != .temporarilyUnavailable {
                HStack {
                    Button(KeyameleonAppMetadata.requestPermissionButtonTitle) {
                        model.requestPermission()
                    }
                    .disabled(model.switchingStatus == .ready)
                    .accessibilityIdentifier(KeyameleonAppMetadata.requestPermissionAccessibilityIdentifier)

                    Button(
                        model.switchingStatus == .ready
                            ? KeyameleonAppMetadata.continueToAssignmentsButtonTitle
                            : KeyameleonAppMetadata.continueWithoutPermissionButtonTitle
                    ) {
                        model.continueToAssignments()
                    }
                    .accessibilityIdentifier(KeyameleonAppMetadata.continueToAssignmentsAccessibilityIdentifier)
                }

                recoveryActions
            }
        }
    }

    private var operationalNotificationSetup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(KeyameleonAppMetadata.operationalNotificationSetupTitle)
                .font(.headline)

            Text(KeyameleonAppMetadata.operationalNotificationSetupExplanation)
                .font(.callout)
                .foregroundStyle(.secondary)

            Text(model.notificationAuthorizationState.displayName)
                .font(.callout)
                .accessibilityLabel(KeyameleonAppMetadata.notificationAuthorizationLabel)
                .accessibilityValue(model.notificationAuthorizationState.displayName)

            HStack {
                if model.notificationAuthorizationState == .notDetermined {
                    Button(KeyameleonAppMetadata.enableOperationalNotificationsButtonTitle) {
                        model.requestOperationalNotificationAuthorization()
                    }
                    .accessibilityLabel(KeyameleonAppMetadata.enableOperationalNotificationsButtonTitle)
                }

                Button(KeyameleonAppMetadata.skipOperationalNotificationsButtonTitle) {
                    model.dismissOperationalNotificationSetup()
                }
                .accessibilityLabel(KeyameleonAppMetadata.skipOperationalNotificationsButtonTitle)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier(KeyameleonAppMetadata.operationalNotificationSetupAccessibilityIdentifier)
    }

    private var assignmentSetup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Name each Physical Keyboard and create Keyboard Assignments. Changes save immediately.")

            Text(KeyameleonAppMetadata.assignmentAppliesAfterActivation)
                .foregroundStyle(.secondary)

            switchingStatus
            activePhysicalKeyboardStatus
            switchingWarnings

            HStack {
                Button(KeyameleonAppMetadata.finishWithoutAssignmentsButtonTitle) {
                    model.finishWithoutAssignments()
                }
                .accessibilityIdentifier(KeyameleonAppMetadata.finishWithoutAssignmentsAccessibilityIdentifier)
            }

            recoveryActions
        }
    }

    private var completedSetup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Guided setup is complete. Keyameleon remains in Menu first mode.")
                .foregroundStyle(.secondary)

            switchingStatus
            activePhysicalKeyboardStatus
            switchingWarnings

            Text(switchingStatusExplanation(for: model.switchingStatus))

            Text("Keyameleon does not provide a First-Key Guarantee. Events before verification can use the previous Input Source.")
                .foregroundStyle(.secondary)

            recoveryActions
        }
    }

    private var switchingStatus: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Switching Status")
                .font(.headline)
                .accessibilityIdentifier(KeyameleonAppMetadata.switchingStatusAccessibilityIdentifier)
            Text(model.switchingStatus.displayName)
                .font(.title3)
                .accessibilityValue(model.switchingStatus.displayName)

            if let reason = model.temporaryUnavailableReason {
                Text("\(KeyameleonAppMetadata.switchingStatusReasonMenuItemPrefix) \(reason.displayName)")
                    .font(.callout)
                    .accessibilityLabel(KeyameleonAppMetadata.switchingStatusReasonMenuItemPrefix)
                    .accessibilityValue(reason.displayName)

                Text(KeyameleonAppMetadata.temporarilyUnavailableAutomaticRecovery)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Switching Status")
    }

    private var activePhysicalKeyboardStatus: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(KeyameleonAppMetadata.activePhysicalKeyboardLabel)
                .font(.headline)
            Text(
                model.activePhysicalKeyboard?.name
                    ?? KeyameleonAppMetadata.noActivityObservedYet
            )
            .font(.title3)
            .accessibilityValue(
                model.activePhysicalKeyboard?.name
                    ?? KeyameleonAppMetadata.noActivityObservedYet
            )

            if let mismatch = model.activeInputSourceMismatch {
                inputSourceMismatchStatus(mismatch)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(KeyameleonAppMetadata.activePhysicalKeyboardLabel)
        .accessibilityIdentifier(KeyameleonAppMetadata.activePhysicalKeyboardAccessibilityIdentifier)
    }

    private func inputSourceMismatchStatus(
        _ mismatch: InputSourceMismatchPresentation
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(KeyameleonAppMetadata.currentInputSourceLabel): \(mismatch.currentName)")
                .font(.callout)
            Text("\(KeyameleonAppMetadata.assignedInputSourceLabel): \(mismatch.assignedName)")
                .font(.callout)
            Text(mismatch.restorationExplanation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(KeyameleonAppMetadata.currentInputSourceLabel) \(mismatch.currentName). \(KeyameleonAppMetadata.assignedInputSourceLabel) \(mismatch.assignedName). \(mismatch.restorationExplanation)"
        )
    }

    @ViewBuilder
    private var switchingWarnings: some View {
        if !model.activeWarnings.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(KeyameleonAppMetadata.switchingWarningsSectionTitle)
                    .font(.headline)

                ForEach(model.activeWarnings) { warning in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(warning.category.displayName)
                            .font(.body.weight(.semibold))

                        Text(recoveryExplanation(for: warning))
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        if warning.supportsRetryNow {
                            Button(KeyameleonAppMetadata.retryNowButtonTitle) {
                                model.retryNow()
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(warning.category.displayName)
                    .accessibilityValue(warning.recoveryAction.displayName)
                }
            }
        }
    }

    private func recoveryExplanation(for warning: SwitchingWarning) -> String {
        switch warning.category {
        case .selectionFailed:
            KeyameleonAppMetadata.selectionFailedRecoveryExplanation
        case .unavailableKeyboardAssignment:
            KeyameleonAppMetadata.unavailableKeyboardAssignmentRecoveryExplanation
        }
    }

    @ViewBuilder
    private var recoveryActions: some View {
        if model.switchingStatus != .temporarilyUnavailable {
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

    private var configuration: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Physical Keyboards")
                .font(.headline)

            if let designationStatus = model.manualDesignationStatusText() {
                VStack(alignment: .leading, spacing: 8) {
                    Text(designationStatus)
                        .foregroundStyle(.secondary)
                    Button(KeyameleonAppMetadata.manualDesignationCancelButtonTitle) {
                        model.cancelManualDesignation()
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }

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
        .accessibilityIdentifier(KeyameleonAppMetadata.physicalKeyboardConfigurationAccessibilityIdentifier)
    }

    private func physicalKeyboardRow(_ physicalKeyboard: PhysicalKeyboard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if physicalKeyboard.isAssignable {
                    Text(KeyameleonAppMetadata.physicalKeyboardNameLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(physicalKeyboard.name)
                        .font(.body.weight(.medium))
                }

                Spacer()

                if physicalKeyboard.isActive {
                    Text(KeyameleonAppMetadata.activePhysicalKeyboardLabel)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.15), in: Capsule())
                }
            }

            if physicalKeyboard.isAssignable {
                TextField(
                    physicalKeyboard.productName,
                    text: nameBinding(for: physicalKeyboard)
                )
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(
                    "\(KeyameleonAppMetadata.physicalKeyboardNameLabel) for \(physicalKeyboard.name)"
                )
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
            }

            Text(connectionDescription(for: physicalKeyboard))
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

                HStack {
                    if physicalKeyboard.connectionState == .connected,
                       !model.replaceCandidates(for: physicalKeyboard.id).isEmpty
                    {
                        Button(KeyameleonAppMetadata.replaceSavedPhysicalKeyboardButtonTitle) {
                            pendingReplaceConnectedID = physicalKeyboard.id
                            replacePickerKeyboardID = physicalKeyboard.id
                        }
                    }

                    if model.canForgetPhysicalKeyboard(physicalKeyboard.id) {
                        Button(KeyameleonAppMetadata.forgetPhysicalKeyboardButtonTitle, role: .destructive) {
                            forgetCandidateID = physicalKeyboard.id
                        }
                    }
                }
            } else if model.canStartManualDesignation(for: physicalKeyboard.id) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(KeyameleonAppMetadata.manualDesignationExplanation)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button(KeyameleonAppMetadata.manualDesignationButtonTitle) {
                        model.startManualDesignation(for: physicalKeyboard.id)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            model.activePhysicalKeyboardID == physicalKeyboard.id
                ? Color.accentColor.opacity(0.15)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .topTrailing) {
            if model.activePhysicalKeyboardID == physicalKeyboard.id {
                Text("Active")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.tint.opacity(0.2), in: Capsule())
                    .padding(8)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(physicalKeyboard.name)
        .accessibilityValue(
            model.activePhysicalKeyboardID == physicalKeyboard.id
                ? "\(KeyameleonAppMetadata.activePhysicalKeyboardLabel) · \(connectionDescription(for: physicalKeyboard))"
                : connectionDescription(for: physicalKeyboard)
        )
    }

    private func switchingStatusExplanation(for status: SwitchingStatus) -> String {
        switch status {
        case .ready:
            "Activity-Triggered Switching can observe Activation Activity."
        case .permissionRequired:
            "Physical Keyboard observation and Input Source requests remain stopped until listen permission is available."
        case .paused:
            "Activity-Triggered Switching is paused. Key Content observation and Input Source requests are stopped. Management and settings stay available."
        case .temporarilyUnavailable:
            if let reason = model.temporaryUnavailableReason {
                "Activity-Triggered Switching is temporarily unavailable because \(reason.displayName). \(KeyameleonAppMetadata.temporarilyUnavailableAutomaticRecovery)"
            } else {
                KeyameleonAppMetadata.temporarilyUnavailableAutomaticRecovery
            }
        }
    }

    private func connectionDescription(for physicalKeyboard: PhysicalKeyboard) -> String {
        let hardware =
            physicalKeyboard.isBuiltIn
            ? "Built-in"
            : physicalKeyboard.transport.displayName
        let connection = physicalKeyboard.connectionState.displayName
        if physicalKeyboard.connectionState == .disconnected {
            return connection
        }

        return "\(connection) · \(hardware)"
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
                .accessibilityAddTraits(.isHeader)

            Text(physicalKeyboard.name)
                .foregroundStyle(.secondary)

            Text(KeyameleonAppMetadata.assignmentAppliesAfterActivation)
                .font(.callout)
                .foregroundStyle(.secondary)

            TextField(KeyameleonAppMetadata.assignmentSearchPrompt, text: $query)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(KeyameleonAppMetadata.assignmentSearchPrompt)

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
                    .accessibilityLabel(inputSource.name)
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

@MainActor
private struct ReplaceSavedPhysicalKeyboardPickerView: View {
    let physicalKeyboard: PhysicalKeyboard
    let candidates: [PhysicalKeyboard]
    let onSelect: (PhysicalKeyboard) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(KeyameleonAppMetadata.replaceSavedPhysicalKeyboardPickerTitle)
                .font(.title2)

            Text("Move a disconnected saved Physical Keyboard onto \(physicalKeyboard.name).")
                .foregroundStyle(.secondary)

            if candidates.isEmpty {
                Text("No disconnected saved Physical Keyboards.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List(candidates) { candidate in
                    Button {
                        onSelect(candidate)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(candidate.name)
                            Text(candidate.statusDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 360, minHeight: 360)
    }
}

@MainActor
private struct ManualPhysicalKeyboardDesignationNameSheet: View {
    @Binding var nameDraft: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(KeyameleonAppMetadata.manualDesignationConfirmNameButtonTitle)
                .font(.title2)

            Text(KeyameleonAppMetadata.manualDesignationExplanation)
                .foregroundStyle(.secondary)

            Text(KeyameleonAppMetadata.manualDesignationNameFieldLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(
                KeyameleonAppMetadata.physicalKeyboardNameLabel,
                text: $nameDraft
            )
            .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button(KeyameleonAppMetadata.manualDesignationCancelButtonTitle, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(KeyameleonAppMetadata.manualDesignationConfirmNameButtonTitle) {
                    onConfirm()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 360)
    }
}
