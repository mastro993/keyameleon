import SwiftUI

@MainActor
struct OnboardingKeyboardRow: View {
    let row: OnboardingPhysicalKeyboardRow
    let model: KeyameleonSetupModel
    let onExclude: (PhysicalKeyboardRecordID) -> Void
    let onIncludeAgain: (String) -> Void

    var body: some View {
        HStack(spacing: 16) {
            switch row.state {
            case let .included(keyboard):
                VStack(alignment: .leading, spacing: 3) {
                    Text(keyboard.name)
                        .font(.title2)
                        .bold()
                        .foregroundStyle(OnboardingPalette.primary)
                    Text(subtitle(for: keyboard))
                        .font(.title3)
                        .foregroundStyle(OnboardingPalette.muted)
                }
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    if model.canExcludePhysicalKeyboard(keyboard.id) {
                        OnboardingKeyboardInclusionButton(
                            isIncluded: true, isDisabled: hasPersistenceError
                        ) { onExclude(keyboard.id) }
                    }
                    if keyboard.isAssignable {
                        Picker("Input Source for \(keyboard.name)", selection: Binding(
                            get: { keyboard.keyboardAssignment?.inputSourceIdentifier },
                            set: { model.setKeyboardAssignment(keyboard.id, inputSourceIdentifier: $0) }
                        )) {
                            Text("No Input Source assigned").tag(nil as String?)
                            if let identifier = keyboard.keyboardAssignment?.inputSourceIdentifier,
                               !model.eligibleInputSources.contains(where: { $0.identifier == identifier }) {
                                Text("Unavailable Input Source").tag(Optional(identifier)).disabled(true)
                            }
                            ForEach(model.eligibleInputSources) { source in
                                Text(source.name).tag(Optional(source.identifier))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 176)
                        .disabled(model.eligibleInputSources.isEmpty || hasPersistenceError)
                    } else {
                        Text("Unsupported")
                            .foregroundStyle(OnboardingPalette.secondary)
                            .frame(width: 176, alignment: .leading)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            case let .excluded(exclusion, savedRecord):
                VStack(alignment: .leading, spacing: 3) {
                    Text(excludedName(exclusion, savedRecord: savedRecord))
                        .font(.title2)
                        .bold()
                        .foregroundStyle(OnboardingPalette.muted)
                    Text(excludedSubtitle(savedRecord))
                        .font(.title3)
                        .foregroundStyle(OnboardingPalette.muted)
                }
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    OnboardingKeyboardInclusionButton(
                        isIncluded: false, isDisabled: hasPersistenceError
                    ) { onIncludeAgain(exclusion.key) }
                    switch savedRecord {
                    case let .matched(record):
                        Picker(
                            "Input Source for \(record.name)",
                            selection: .constant(record.keyboardAssignment?.inputSourceIdentifier)
                        ) {
                            Text("No Input Source assigned").tag(nil as String?)
                            if let identifier = record.keyboardAssignment?.inputSourceIdentifier,
                               !model.eligibleInputSources.contains(where: { $0.identifier == identifier }) {
                                Text("Unavailable Input Source").tag(Optional(identifier))
                            }
                            ForEach(model.eligibleInputSources) { source in
                                Text(source.name).tag(Optional(source.identifier))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 176)
                        .disabled(true)
                    case .missing, .ambiguous:
                        Text("Assignment unavailable")
                            .foregroundStyle(OnboardingPalette.muted)
                            .frame(width: 176, alignment: .leading)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .accessibilityElement(children: .contain)
    }

    private var hasPersistenceError: Bool {
        model.persistenceError != nil || model.activityTriggeredSwitching.persistenceError != nil
    }

    private func excludedName(
        _ exclusion: SavedPhysicalKeyboardExclusion,
        savedRecord: OnboardingPhysicalKeyboardRow.SavedRecordSelection
    ) -> String {
        if case let .matched(record) = savedRecord { return record.name }
        return exclusion.name
    }

    private func excludedSubtitle(_ savedRecord: OnboardingPhysicalKeyboardRow.SavedRecordSelection) -> String {
        if case let .matched(record) = savedRecord { return "\(record.productName) · Excluded" }
        return "Excluded"
    }

    private func subtitle(for keyboard: PhysicalKeyboard) -> String {
        if case let .unsupported(reason) = keyboard.assignmentState {
            let detail = switch reason {
            case .missingIdentity: "Identity unavailable"
            case .unstableIdentity: "Identity unstable"
            case .sharedIdentity: "Identity shared"
            case .ambiguousIdentity: "Identity ambiguous"
            }
            return "Unsupported · \(detail)"
        }
        if keyboard.connectionState == .disconnected { return "Disconnected" }
        if keyboard.isBuiltIn { return "Built-in" }
        let connection = switch keyboard.transport {
        case .usb: "USB"
        case .bluetooth: "Bluetooth"
        case .bluetoothLowEnergy: "Bluetooth"
        case .other: "Connected"
        }
        let status = connection == "Connected" ? connection : "\(connection) · Connected"
        return keyboard.name == keyboard.productName
            ? status
            : "\(keyboard.productName) · \(status)"
    }
}

#if DEBUG
#Preview("Assignment row") {
    let fixture = KeyameleonPreviewFixtures.setup(.assignmentsPopulated)
    if let keyboard = fixture.model.physicalKeyboards.first {
        OnboardingKeyboardRow(
            row: OnboardingPhysicalKeyboardRow(physicalKeyboard: keyboard, exclusionKey: nil),
            model: fixture.model,
            onExclude: { _ in },
            onIncludeAgain: { _ in }
        )
        .frame(width: 630)
    }
}
#endif
