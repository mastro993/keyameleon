import AppKit
import SwiftUI

private enum KeyameleonSettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case keyboard = "Keyboard"
    case diagnostics = "Diagnostics"

    var id: Self { self }
}

@MainActor
struct KeyameleonSettingsView: View {
    @ObservedObject private var model: KeyameleonGeneralSettingsModel
    private let setupModel: KeyameleonSetupModel
    @State private var selectedTab = KeyameleonSettingsTab.general

    init(
        model: KeyameleonGeneralSettingsModel,
        setupModel: KeyameleonSetupModel
    ) {
        _model = ObservedObject(wrappedValue: model)
        self.setupModel = setupModel
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Settings section", selection: $selectedTab) {
                ForEach(KeyameleonSettingsTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 360)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider()

            switch selectedTab {
            case .general:
                generalSettings
            case .keyboard:
                KeyameleonKeyboardSettingsView(model: setupModel)
            case .diagnostics:
                diagnosticsSettings
            }
        }
        .frame(minWidth: 580, minHeight: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: model.refresh)
    }

    private var generalSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                settingsSection(title: "Startup") {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle("Launch Keyameleon at login", isOn: launchAtLoginBinding)
                            .toggleStyle(.switch)

                        if model.launchAtLoginError != nil {
                            Divider()
                            Text(
                                "Could not change Launch at Login. Open System Settings → General → Login Items if macOS requires approval."
                            )
                            .font(.callout)
                            .foregroundStyle(.red)
                        }
                    }
                } footer: {
                    Text("Starts Keyameleon when you log in.")
                }

                settingsSection(title: "Operational Notifications") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Authorization")
                            Spacer()
                            Text(notificationAuthorizationName(model.notificationAuthorizationState))
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Notification Authorization")
                        .accessibilityValue(
                            notificationAuthorizationName(model.notificationAuthorizationState)
                        )

                        Divider()

                        HStack {
                            if model.notificationAuthorizationState == .notDetermined {
                                Button("Enable Notifications") {
                                    model.requestOperationalNotificationAuthorization()
                                }
                            }

                            Spacer()

                            Button("Open System Settings…") {
                                model.openNotificationSettings()
                            }
                        }
                    }
                } footer: {
                    Text(
                        "Optional alerts for revoked Input Monitoring permission or unavailable Keyboard Assignments. Keyameleon never requests sound or badge access."
                    )
                }
            }
            .padding(28)
        }
    }

    private var diagnosticsSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                settingsSection(title: "Diagnostic Session") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Status")
                            Spacer()
                            Text(model.isDiagnosticSessionActive
                                ? "Active · ends after 10 minutes"
                                : "Inactive")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Diagnostic Session")
                        .accessibilityValue(
                            model.isDiagnosticSessionActive
                                ? "Active, ends automatically after 10 minutes"
                                : "Inactive"
                        )

                        Divider()

                        HStack {
                            Button(model.isDiagnosticSessionActive
                                ? "Stop Diagnostic Session"
                                : "Start Diagnostic Session") {
                                if model.isDiagnosticSessionActive {
                                    model.stopDiagnosticSession()
                                } else {
                                    model.startDiagnosticSession()
                                }
                            }

                            Spacer()

                            Text(
                                "\(model.diagnosticRecordCount) records · about \(model.diagnosticEstimatedByteCount) bytes"
                            )
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        }

                        Divider()

                        Button("Clear All Diagnostic Data", role: .destructive) {
                            model.clearAllDiagnosticData()
                        }
                        .disabled(model.diagnosticRecordCount == 0)
                    }
                } footer: {
                    Text(
                        "Retention stops at 7 days or 5 MB. Diagnostic Data never includes Key Content, serial numbers, custom names, assignments, paths, user names, or application names."
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Diagnostic Bundle")
                        .font(.title3.weight(.semibold))
                    KeyameleonDiagnosticBundleReviewView(model: model)
                }
            }
            .padding(28)
        }
    }

    private func settingsSection<Content: View, Footer: View>(
        title: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))

            content()
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color.primary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )

            footer()
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.isLaunchAtLoginEnabled },
            set: { model.setLaunchAtLoginEnabled($0) }
        )
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
}

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

private struct SettingsCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
    }
}

private extension View {
    func settingsCardStyle() -> some View {
        modifier(SettingsCardStyle())
    }
}

@MainActor
struct KeyameleonAboutView: View {
    @ObservedObject private var model: KeyameleonGeneralSettingsModel

    init(model: KeyameleonGeneralSettingsModel) {
        _model = ObservedObject(wrappedValue: model)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 28)

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 80, height: 80)
                .accessibilityLabel("Keyameleon app icon")

            Text(appName)
                .font(.title2.weight(.semibold))
                .padding(.top, 18)
                .accessibilityAddTraits(.isHeader)

            Text("Version \(version)")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Text("GPL-3.0-only licensed open source.")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.6))
                .padding(.top, 5)

            Divider()
                .padding(.vertical, 24)
                .frame(maxWidth: 332)

            Button(action: model.checkForUpdates) {
                Label("Check for Updates…", systemImage: "arrow.clockwise.circle")
            }
            .controlSize(.regular)
            .disabled(!model.canCheckForUpdates)
            .accessibilityHint("Checks whether a newer Keyameleon version is available")

            Spacer(minLength: 28)
        }
        .padding(.horizontal, 24)
        .frame(width: 380, height: 320)
    }

    private var appName: String {
        nonemptyBundleString(for: "CFBundleDisplayName")
            ?? nonemptyBundleString(for: "CFBundleName")
            ?? "Keyameleon"
    }

    private var version: String {
        nonemptyBundleString(for: "CFBundleShortVersionString") ?? "—"
    }

    private func nonemptyBundleString(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
