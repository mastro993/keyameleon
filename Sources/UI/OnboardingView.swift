import AppKit
import SwiftUI

@MainActor
struct KeyameleonOnboardingView: View {
    private let model: KeyameleonSetupModel
    private let switching: ActivityTriggeredSwitching
    @State private var assignmentPickerKeyboardID: PhysicalKeyboardRecordID?

    init(model: KeyameleonSetupModel, switching: ActivityTriggeredSwitching) {
        self.model = model
        self.switching = switching
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
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 72, height: 72)
                .accessibilityLabel("Keyameleon app icon")

            Text("Keyameleon")
                .font(.largeTitle.weight(.semibold))
                .accessibilityAddTraits(.isHeader)

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
            "Connect every Physical Keyboard you use with this Mac and assign an Input Source. You can finish this later in Settings."
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
            if model.physicalKeyboards.isEmpty {
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
                VStack(spacing: 12) {
                    ForEach(model.physicalKeyboards) { physicalKeyboard in
                        OnboardingPhysicalKeyboardCard(
                            physicalKeyboard: physicalKeyboard,
                            assignedInputSourceName: model.assignedInputSourceName(
                                for: physicalKeyboard
                            ),
                            onAssign: {
                                assignmentPickerKeyboardID = physicalKeyboard.id
                            }
                        )
                    }
                }
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

@MainActor
struct OnboardingPhysicalKeyboardCard: View {
    let physicalKeyboard: PhysicalKeyboard
    let assignedInputSourceName: String?
    let onAssign: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(physicalKeyboard.name)
                    .font(.headline)
                Spacer()
                Text(connectionLabel)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text(assignmentLabel)
                .font(.callout)
                .foregroundStyle(physicalKeyboard.isAssignable ? Color.secondary : Color.orange)

            if physicalKeyboard.isAssignable {
                Button(
                    assignedInputSourceName == nil ? "Assign Input Source" : "Change Input Source",
                    action: onAssign
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.primary.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(physicalKeyboard.name)
        .accessibilityValue("\(connectionLabel). \(assignmentLabel)")
    }

    private var connectionLabel: String {
        switch physicalKeyboard.connectionState {
        case .connected:
            "Connected"
        case .disconnected:
            "Disconnected"
        }
    }

    private var assignmentLabel: String {
        switch physicalKeyboard.assignmentState {
        case .unassigned:
            "No Input Source assigned"
        case .assigned:
            if let assignedInputSourceName {
                assignedInputSourceName
            } else {
                "Unavailable Keyboard Assignment"
            }
        case let .unsupported(reason):
            unsupportedReasonName(reason)
        }
    }

    private func unsupportedReasonName(_ reason: PhysicalKeyboardUnsupportedReason) -> String {
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
