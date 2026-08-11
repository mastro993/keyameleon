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
                Text(model.isSetupComplete ? "Keyameleon" : "Guided setup")
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
            .accessibilityIdentifier("guided-setup")
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
            if let forgetCandidateID,
               let physicalKeyboard = model.physicalKeyboards.first(where: { $0.id == forgetCandidateID })
            {
                Text(forgetConfirmationMessage(for: physicalKeyboard))
            }
        }
        .confirmationDialog(
            "Replace Saved Physical Keyboard?",
            isPresented: replaceConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Replace", role: .destructive) {
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
               let replaceTargetDisconnectedID,
               let connected = model.physicalKeyboards.first(where: { $0.id == pendingReplaceConnectedID }),
               let disconnected = model.physicalKeyboards.first(where: { $0.id == replaceTargetDisconnectedID })
            {
                Text(replaceConfirmationMessage(replacing: disconnected, with: connected))
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

    private func forgetConfirmationMessage(for physicalKeyboard: PhysicalKeyboard) -> String {
        let removedData =
            "This removes the saved Physical Keyboard Name, Keyboard Assignment, Manual Physical Keyboard Designation, and linked Diagnostic Data for \(physicalKeyboard.name)."
        let reconnectResult =
            switch physicalKeyboard.connectionState {
            case .connected:
                "This connected Physical Keyboard reappears as new and unassigned."
            case .disconnected:
                "This disconnected Physical Keyboard disappears."
            }

        return "\(removedData) \(reconnectResult)"
    }

    private func replaceConfirmationMessage(
        replacing disconnected: PhysicalKeyboard,
        with connected: PhysicalKeyboard
    ) -> String {
        """
        Move the Physical Keyboard Name and Keyboard Assignment from \(disconnected.name) to \(connected.name)? \
        The old saved record is removed. If the old hardware returns later, it appears as new and unassigned.
        """
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
                    Button("Request Permission") {
                        model.requestPermission()
                    }
                    .disabled(model.switchingStatus == .ready)
                    .accessibilityIdentifier("request-permission")

                    Button(
                        model.switchingStatus == .ready
                            ? "Continue to Assignments"
                            : "Continue Without Permission"
                    ) {
                        model.continueToAssignments()
                    }
                    .accessibilityIdentifier("continue-to-assignments")
                }

                recoveryActions
            }
        }
    }

    private var operationalNotificationSetup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Optional operational notifications")
                .font(.headline)

            Text(
                "Keyameleon can alert you only when listen permission is revoked or a Keyboard Assignment becomes unavailable. It requests alert access only. It does not request sound or icon badge access."
            )
                .font(.callout)
                .foregroundStyle(.secondary)

            Text(notificationAuthorizationName(model.notificationAuthorizationState))
                .font(.callout)
                .accessibilityLabel("Notification Authorization")
                .accessibilityValue(notificationAuthorizationName(model.notificationAuthorizationState))

            HStack {
                if model.notificationAuthorizationState == .notDetermined {
                    Button("Enable Operational Notifications") {
                        model.requestOperationalNotificationAuthorization()
                    }
                    .accessibilityLabel("Enable Operational Notifications")
                }

                Button("Not Now") {
                    model.dismissOperationalNotificationSetup()
                }
                .accessibilityLabel("Not Now")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("operational-notification-setup")
    }

    private var assignmentSetup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Name each Physical Keyboard and create Keyboard Assignments. Changes save immediately.")

            Text("Applies after next Activation Activity")
                .foregroundStyle(.secondary)

            switchingStatus
            activePhysicalKeyboardStatus
            switchingWarnings

            HStack {
                Button("Finish Without Assignments") {
                    model.finishWithoutAssignments()
                }
                .accessibilityIdentifier("finish-without-assignments")
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
                .accessibilityIdentifier("switching-status")
            Text(switchingStatusName(model.switchingStatus))
                .font(.title3)
                .accessibilityValue(switchingStatusName(model.switchingStatus))

            if let reason = model.temporaryUnavailableReason {
                Text("Detected reason: \(unavailableReasonName(reason))")
                    .font(.callout)
                    .accessibilityLabel("Detected reason:")
                    .accessibilityValue(unavailableReasonName(reason))

                Text("Resumes automatically when macOS allows Activity-Triggered Switching.")
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
            Text("Active")
                .font(.headline)
            Text(
                model.activePhysicalKeyboard?.name
                    ?? "No activity observed yet"
            )
            .font(.title3)
            .accessibilityValue(
                model.activePhysicalKeyboard?.name
                    ?? "No activity observed yet"
            )

            if let mismatch = model.activeInputSourceMismatch {
                inputSourceMismatchStatus(mismatch)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Active")
        .accessibilityIdentifier("active-physical-keyboard")
    }

    private func inputSourceMismatchStatus(
        _ mismatch: InputSourceMismatch
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(
                "Current Input Source: \(inputSourceName(for: mismatch.currentInputSourceIdentifier))"
            )
                .font(.callout)
            Text(
                "Assigned Input Source: \(inputSourceName(for: mismatch.assignedInputSourceIdentifier))"
            )
                .font(.callout)
            Text("Later Activation Activity restores the Keyboard Assignment.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Current Input Source \(inputSourceName(for: mismatch.currentInputSourceIdentifier)). Assigned Input Source \(inputSourceName(for: mismatch.assignedInputSourceIdentifier)). Later Activation Activity restores the Keyboard Assignment."
        )
    }

    @ViewBuilder
    private var switchingWarnings: some View {
        if !model.activeWarnings.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Warnings")
                    .font(.headline)

                ForEach(model.activeWarnings) { warning in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(switchingFailureCategoryName(warning.category))
                            .font(.body.weight(.semibold))

                        Text(recoveryExplanation(for: warning))
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        if warning.supportsRetryNow {
                            Button("Retry Now") {
                                model.retryNow()
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(switchingFailureCategoryName(warning.category))
                    .accessibilityValue(recoveryActionName(warning.recoveryAction))
                }
            }
        }
    }

    private func recoveryExplanation(for warning: SwitchingWarning) -> String {
        switch warning.category {
        case .selectionFailed:
            "Normal input is unchanged. Retry Now retries the current wanted Keyboard Assignment. Later Activation Activity can also start a new request."
        case .unavailableKeyboardAssignment:
            "The saved Keyboard Assignment remains. Change Assignment or Remove Assignment. Switching restores automatically only when the exact saved Input Source identifier returns."
        }
    }

    @ViewBuilder
    private var recoveryActions: some View {
        if model.switchingStatus != .temporarilyUnavailable {
            HStack {
                Button("Open System Settings") {
                    model.openSystemSettings()
                }

                Button("Check Again") {
                    model.refreshPermission()
                }
            }
        }
    }

    private var configuration: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Physical Keyboards")
                .font(.headline)

            if let designationStatus = manualDesignationMessage(for: model.manualDesignationPhase) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(designationStatus)
                        .foregroundStyle(.secondary)
                    Button("Cancel Designation") {
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
                Text("Applies after next Activation Activity")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
        .accessibilityIdentifier("physical-keyboard-configuration")
    }

    private func physicalKeyboardRow(_ physicalKeyboard: PhysicalKeyboard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if physicalKeyboard.isAssignable {
                    Text("Physical Keyboard Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(physicalKeyboard.name)
                        .font(.body.weight(.medium))
                }

                Spacer()

                if physicalKeyboard.isActive {
                    Text("Active")
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
                    "Physical Keyboard Name for \(physicalKeyboard.name)"
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
                            ? "Assign…"
                            : "Change Assignment"
                    ) {
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
                }

                HStack {
                    if physicalKeyboard.connectionState == .connected,
                       !model.replaceCandidates(for: physicalKeyboard.id).isEmpty
                    {
                        Button("Replace Saved Physical Keyboard…") {
                            pendingReplaceConnectedID = physicalKeyboard.id
                            replacePickerKeyboardID = physicalKeyboard.id
                        }
                    }

                    if model.canForgetPhysicalKeyboard(physicalKeyboard.id) {
                        Button("Forget Physical Keyboard…", role: .destructive) {
                            forgetCandidateID = physicalKeyboard.id
                        }
                    }
                }
            } else if model.canStartManualDesignation(for: physicalKeyboard.id) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(
                        "Keyameleon can save this external identity group as a Physical Keyboard only after it leaves, returns, and you confirm its name."
                    )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Manual Physical Keyboard Designation…") {
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
                ? "Active · \(connectionDescription(for: physicalKeyboard))"
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
                "Activity-Triggered Switching is temporarily unavailable because \(unavailableReasonName(reason)). Resumes automatically when macOS allows Activity-Triggered Switching."
            } else {
                "Resumes automatically when macOS allows Activity-Triggered Switching."
            }
        }
    }

    private func connectionDescription(for physicalKeyboard: PhysicalKeyboard) -> String {
        let hardware =
            physicalKeyboard.isBuiltIn
            ? "Built-in"
            : transportName(physicalKeyboard.transport)
        let connection = connectionStateName(physicalKeyboard.connectionState)
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
            if let name = model.assignedInputSourceName(for: physicalKeyboard) {
                "Keyboard Assignment: \(name)"
            } else {
                "Unavailable Keyboard Assignment"
            }
        case let .unsupported(reason):
            "Unsupported — \(unsupportedReasonName(reason))"
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

    private func inputSourceName(for identifier: String) -> String {
        model.eligibleInputSources.first { $0.identifier == identifier }?.name ?? identifier
    }

    private func switchingStatusName(_ status: SwitchingStatus) -> String {
        switch status {
        case .ready:
            "Ready"
        case .permissionRequired:
            "Permission Required"
        case .paused:
            "Paused"
        case .temporarilyUnavailable:
            "Temporarily Unavailable"
        }
    }

    private func unavailableReasonName(_ reason: SwitchingUnavailableReason) -> String {
        switch reason {
        case .sleeping:
            "macOS is asleep"
        case .inactiveSession:
            "The user session is inactive"
        case .secureInput:
            "Secure Input is active"
        case .protectedDataUnavailable:
            "Protected data is unavailable"
        }
    }

    private func notificationAuthorizationName(
        _ state: OperationalNotificationAuthorizationState
    ) -> String {
        switch state {
        case .unknown:
            "Checking"
        case .notDetermined:
            "Not requested"
        case .denied:
            "Denied"
        case .authorized:
            "Authorized"
        }
    }

    private func switchingFailureCategoryName(_ category: SwitchingFailureCategory) -> String {
        switch category {
        case .selectionFailed:
            "Selection failed"
        case .unavailableKeyboardAssignment:
            "Unavailable Keyboard Assignment"
        }
    }

    private func recoveryActionName(_ action: SwitchingRecoveryAction) -> String {
        switch action {
        case .retryNow:
            "Retry Now"
        case .changeOrRemoveAssignment:
            "Change Assignment or Remove Assignment"
        }
    }

    private func manualDesignationMessage(
        for phase: ManualPhysicalKeyboardDesignationPhase
    ) -> String? {
        switch phase {
        case .idle:
            nil
        case .awaitingRemoval:
            "Unplug or turn off this Physical Keyboard, then return it."
        case .awaitingReturn:
            "Return the same Physical Keyboard to continue."
        case .awaitingNameConfirmation:
            "Confirm the Physical Keyboard Name to save Manual Physical Keyboard Designation."
        }
    }

    private func transportName(_ transport: PhysicalKeyboardTransport) -> String {
        switch transport {
        case .usb:
            "USB"
        case .bluetooth:
            "Bluetooth"
        case .bluetoothLowEnergy:
            "Bluetooth Low Energy"
        case .other:
            "Other"
        }
    }

    private func connectionStateName(_ state: PhysicalKeyboardConnectionState) -> String {
        switch state {
        case .connected:
            "Connected"
        case .disconnected:
            "Disconnected"
        }
    }

    private func unsupportedReasonName(_ reason: PhysicalKeyboardUnsupportedReason) -> String {
        switch reason {
        case .missingIdentity:
            "Physical Keyboard Identity unavailable"
        case .unstableIdentity:
            "Physical Keyboard Identity unstable"
        case .sharedIdentity:
            "Physical Keyboard Identity shared"
        case .ambiguousIdentity:
            "Physical Keyboard Identity ambiguous"
        }
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
            Text("Choose Input Source")
                .font(.title2)
                .accessibilityAddTraits(.isHeader)

            Text(physicalKeyboard.name)
                .foregroundStyle(.secondary)

            Text("Applies after next Activation Activity")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextField("Search Input Sources", text: $query)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Search Input Sources")

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

    private func assignmentStatusText(for physicalKeyboard: PhysicalKeyboard) -> String {
        switch physicalKeyboard.assignmentState {
        case .unassigned:
            "Unassigned"
        case .assigned:
            "Assigned"
        case let .unsupported(reason):
            switch reason {
            case .missingIdentity:
                "Unsupported — Physical Keyboard Identity unavailable"
            case .unstableIdentity:
                "Unsupported — Physical Keyboard Identity unstable"
            case .sharedIdentity:
                "Unsupported — Physical Keyboard Identity shared"
            case .ambiguousIdentity:
                "Unsupported — Physical Keyboard Identity ambiguous"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Replace Saved Physical Keyboard")
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
                            Text(assignmentStatusText(for: candidate))
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
            Text("Confirm Physical Keyboard Name")
                .font(.title2)

            Text(
                "Keyameleon can save this external identity group as a Physical Keyboard only after it leaves, returns, and you confirm its name."
            )
                .foregroundStyle(.secondary)

            Text("Physical Keyboard Name")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(
                "Physical Keyboard Name",
                text: $nameDraft
            )
            .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel Designation", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Confirm Physical Keyboard Name") {
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
