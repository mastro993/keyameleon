import AppKit
import SwiftUI

@MainActor
struct KeyameleonOnboardingView: View {
    static let assignmentStepSubtitle = """
    Connect every Physical Keyboard you use with this Mac and assign an Input Source. You can finish this later in Settings.

    When you start typing on a different Physical Keyboard, that first key press can still use the previous Input Source. Keyameleon then selects that keyboard's Keyboard Assignment.
    """

    private let model: KeyameleonSetupModel
    private let switching: ActivityTriggeredSwitching
    @State private var keyboardRows: OnboardingPhysicalKeyboardRows
    @State private var assignmentPickerKeyboardID: PhysicalKeyboardRecordID?
    @State private var excludeCandidateID: PhysicalKeyboardRecordID?

    init(model: KeyameleonSetupModel, switching: ActivityTriggeredSwitching) {
        self.model = model
        self.switching = switching
        _keyboardRows = State(
            initialValue: OnboardingPhysicalKeyboardRows(
                physicalKeyboards: model.physicalKeyboards,
                exclusions: model.excludedPhysicalKeyboards,
                exclusionKeyFor: model.exclusionKey(for:)
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 28)
                .padding(.bottom, 24)

            if model.guidedSetupStep == .assignments {
                keyboardCheck
            } else {
                permissionStep
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("guided-setup")
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
        .confirmationDialog(
            "Not a Physical Keyboard?",
            isPresented: excludeConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Exclude") {
                if let excludeCandidateID {
                    model.excludePhysicalKeyboard(excludeCandidateID)
                    reconcileKeyboardRows()
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
        .onChange(of: model.physicalKeyboards) { _, _ in
            reconcileKeyboardRows()
        }
        .onChange(of: model.excludedPhysicalKeyboards) { _, _ in
            reconcileKeyboardRows()
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 72, height: 72)
                .accessibilityLabel("Keyameleon app icon")

            Text(stepTitle)
                .font(.title2.weight(.semibold))

            Text(stepSubtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
    }

    private var stepTitle: String {
        if model.guidedSetupStep == .assignments {
            "Physical Keyboards"
        } else {
            "Permissions required"
        }
    }

    private var stepSubtitle: String {
        if model.guidedSetupStep == .assignments {
            Self.assignmentStepSubtitle
        } else {
            "Keyameleon needs Input Monitoring to observe Activation Activity from each Physical Keyboard."
        }
    }

    private var permissionStep: some View {
        ListenPermissionOnboardingCard(
            status: listenPermissionCardStatus,
            action: requestListenPermission
        )
        .frame(maxWidth: 520)
    }

    private var keyboardCheck: some View {
        VStack(spacing: 16) {
            if keyboardRows.rows.isEmpty {
                Text("Connect a Physical Keyboard to register it with Keyameleon.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        Color.primary.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(keyboardRows.rows) { row in
                            switch row.state {
                            case let .included(physicalKeyboard):
                                OnboardingPhysicalKeyboardCard(
                                    physicalKeyboard: physicalKeyboard,
                                    assignedInputSourceName: model.assignedInputSourceName(
                                        for: physicalKeyboard
                                    ),
                                    onAssign: {
                                        assignmentPickerKeyboardID = physicalKeyboard.id
                                    },
                                    onExclude: model.canExcludePhysicalKeyboard(physicalKeyboard.id)
                                        ? { excludeCandidateID = physicalKeyboard.id }
                                        : nil
                                )
                            case let .excluded(exclusion):
                                OnboardingExcludedPhysicalKeyboardCard(
                                    exclusion: exclusion
                                ) {
                                    model.restorePhysicalKeyboard(exclusionKey: exclusion.key)
                                    reconcileKeyboardRows()
                                }
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .frame(maxHeight: .infinity)
            }

            Button("Continue", action: completeGuidedSetup)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("continue-guided-setup")
        }
        .frame(maxWidth: 520)
    }

    private var listenPermissionCardStatus: ListenPermissionOnboardingCard.Status {
        if switching.outcome.switchingStatus != .permissionRequired {
            .granted
        } else if model.isWaitingForListenPermission {
            .waiting
        } else {
            .required
        }
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

    private func requestListenPermission() {
        model.requestPermission()
    }

    private func completeGuidedSetup() {
        model.completeSetup()
    }

    private func reconcileKeyboardRows() {
        keyboardRows.reconcile(
            physicalKeyboards: model.physicalKeyboards,
            exclusions: model.excludedPhysicalKeyboards,
            exclusionKeyFor: model.exclusionKey(for:)
        )
    }
}

@MainActor
struct ListenPermissionOnboardingCard: View {
    enum Status {
        case required
        case waiting
        case granted
    }

    let status: Status
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "keyboard")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.tint, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Input Monitoring")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(
                        "Required to observe Activation Activity so Activity-Triggered Switching can select the assigned Input Source."
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    statusRow
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(status == .granted)
        .accessibilityIdentifier("request-permission")
        .accessibilityLabel("Input Monitoring")
        .accessibilityValue(statusAccessibilityValue)
        .accessibilityHint("Shows the system prompt for Input Monitoring.")
    }

    private var statusRow: some View {
        HStack(spacing: 6) {
            switch status {
            case .granted:
                Image(systemName: "checkmark.circle.fill")
                Text("Granted")
            case .waiting:
                ProgressView()
                    .controlSize(.small)
                Text("Waiting…")
            case .required:
                Image(systemName: "hand.tap")
                Text("Grant access")
            }
        }
        .font(.callout.weight(.medium))
        .foregroundStyle(status == .granted ? Color.green : Color.secondary)
    }

    private var cardBackground: Color {
        status == .granted ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.04)
    }

    private var statusAccessibilityValue: String {
        switch status {
        case .granted:
            "Granted"
        case .waiting:
            "Waiting"
        case .required:
            "Required"
        }
    }
}

#if DEBUG
#Preview("Onboarding permission required") {
    let fixture = KeyameleonPreviewFixtures.setup(.permissionRequired)
    KeyameleonOnboardingView(model: fixture.model, switching: fixture.switching)
}

#Preview("Onboarding assignments empty") {
    let fixture = KeyameleonPreviewFixtures.setup(.assignmentsEmpty)
    KeyameleonOnboardingView(model: fixture.model, switching: fixture.switching)
}

#Preview("Onboarding assignments populated") {
    let fixture = KeyameleonPreviewFixtures.setup(.assignmentsPopulated)
    KeyameleonOnboardingView(model: fixture.model, switching: fixture.switching)
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .xxxLarge)
}

#Preview("Onboarding mixed assignment states") {
    let fixture = KeyameleonPreviewFixtures.setup(.mixedAssignments)
    KeyameleonOnboardingView(model: fixture.model, switching: fixture.switching)
}

#Preview("Onboarding excluded device") {
    let fixture = KeyameleonPreviewFixtures.setup(.excludedDevices)
    KeyameleonOnboardingView(model: fixture.model, switching: fixture.switching)
}

#Preview("Onboarding all keyboards excluded") {
    let fixture = KeyameleonPreviewFixtures.setupWithAllKeyboardsExcluded()
    KeyameleonOnboardingView(model: fixture.model, switching: fixture.switching)
}

#Preview("Input Monitoring required") {
    ListenPermissionOnboardingCard(status: .required, action: {})
        .frame(width: 520)
}

#Preview("Input Monitoring waiting") {
    ListenPermissionOnboardingCard(status: .waiting, action: {})
        .frame(width: 520)
}

#Preview("Input Monitoring granted") {
    ListenPermissionOnboardingCard(status: .granted, action: {})
        .frame(width: 520)
        .preferredColorScheme(.dark)
}

#Preview("Physical Keyboard assigned") {
    OnboardingPhysicalKeyboardCard(
        physicalKeyboard: KeyameleonPreviewFixtures.physicalKeyboard(),
        assignedInputSourceName: "Italian",
        onAssign: {},
        onExclude: {}
    )
    .frame(width: 520)
}

#Preview("Physical Keyboard unassigned") {
    OnboardingPhysicalKeyboardCard(
        physicalKeyboard: KeyameleonPreviewFixtures.physicalKeyboard(assignment: nil),
        assignedInputSourceName: nil,
        onAssign: {},
        onExclude: {}
    )
    .frame(width: 520)
}

#Preview("Physical Keyboard disconnected") {
    OnboardingPhysicalKeyboardCard(
        physicalKeyboard: KeyameleonPreviewFixtures.physicalKeyboard(
            name: "Office Keyboard",
            connection: .disconnected
        ),
        assignedInputSourceName: "U.S.",
        onAssign: {},
        onExclude: {}
    )
    .frame(width: 520)
}

#Preview("Physical Keyboard unsupported") {
    OnboardingPhysicalKeyboardCard(
        physicalKeyboard: KeyameleonPreviewFixtures.unsupportedPhysicalKeyboard(
            reason: .ambiguousIdentity
        ),
        assignedInputSourceName: nil,
        onAssign: {},
        onExclude: {}
    )
    .frame(width: 520)
    .environment(\.dynamicTypeSize, .xxxLarge)
}

#Preview("Physical Keyboard built-in") {
    OnboardingPhysicalKeyboardCard(
        physicalKeyboard: KeyameleonPreviewFixtures.physicalKeyboard(
            name: "Built-in Keyboard",
            id: "identity:built-in|anchor:built-in"
        ),
        assignedInputSourceName: "Italian",
        onAssign: {},
        onExclude: nil
    )
    .frame(width: 520)
}
#endif
