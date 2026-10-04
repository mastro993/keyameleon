import SwiftUI

@MainActor
struct OnboardingKeyboardRow: View {
    let row: OnboardingPhysicalKeyboardRow
    let model: KeyameleonSetupModel
    let onExclude: (PhysicalKeyboardRecordID) -> Void
    let onIncludeAgain: (String) -> Void

    @State private var keyboardToRename: PhysicalKeyboard?
    @State private var nameDraft = ""

    var body: some View {
        HStack(spacing: 16) {
            switch row.state {
            case let .included(keyboard):
                VStack(alignment: .leading, spacing: 3) {
                    Text(keyboard.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(OnboardingPalette.primary)
                    Text(row.subtitle(connectedExcludedKeys: model.connectedExcludedKeyboardKeys))
                        .font(.subheadline)
                        .foregroundStyle(OnboardingPalette.muted)
                }
                Spacer(minLength: 0)
                HStack(spacing: 8) {
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
                            .font(.subheadline)
                            .foregroundStyle(OnboardingPalette.secondary)
                            .frame(width: 176, alignment: .leading)
                            .help(unsupportedReason(for: keyboard))
                            .accessibilityValue(unsupportedReason(for: keyboard))
                    }
                    if model.canExcludePhysicalKeyboard(keyboard.id) {
                        Menu {
                            if keyboard.isAssignable && keyboard.id.isIdentityBased {
                                Button("Rename…", systemImage: "pencil") {
                                    presentRename(for: keyboard)
                                }
                            }
                            Button("Hide", systemImage: "eye.slash") {
                                onExclude(keyboard.id)
                            }
                        } label: {
                            Label("Keyboard actions", systemImage: "ellipsis")
                                .labelStyle(.iconOnly)
                                .frame(width: 28, height: 28)
                        }
                        .font(.body)
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .frame(width: 28)
                        .disabled(hasPersistenceError)
                        .accessibilityIdentifier("keyboard-actions")
                    } else {
                        Color.clear.frame(width: 28, height: 28)
                            .accessibilityHidden(true)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            case let .excluded(exclusion, savedRecord):
                VStack(alignment: .leading, spacing: 3) {
                    Text(excludedName(exclusion, savedRecord: savedRecord))
                        .font(.body.weight(.medium))
                        .foregroundStyle(OnboardingPalette.muted)
                    Text(row.subtitle(connectedExcludedKeys: model.connectedExcludedKeyboardKeys))
                        .font(.subheadline)
                        .foregroundStyle(OnboardingPalette.muted)
                }
                Spacer(minLength: 0)
                HStack(spacing: 8) {
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
                            .font(.subheadline)
                            .foregroundStyle(OnboardingPalette.muted)
                            .frame(width: 176, alignment: .leading)
                    }
                    Menu {
                        if case let .matched(record) = savedRecord,
                           record.recordID.isIdentityBased,
                           !record.isBuiltInIdentity {
                            Button("Rename…", systemImage: "pencil") {
                                presentRename(for: .restored(from: record))
                            }
                        }
                        Button("Unhide", systemImage: "eye") {
                            onIncludeAgain(exclusion.key)
                        }
                    } label: {
                        Label("Keyboard actions", systemImage: "ellipsis")
                            .labelStyle(.iconOnly)
                            .frame(width: 28, height: 28)
                    }
                    .font(.body)
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 28)
                    .disabled(hasPersistenceError)
                    .accessibilityIdentifier("keyboard-actions")
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .accessibilityElement(children: .contain)
        .sheet(item: $keyboardToRename) { keyboard in
            PhysicalKeyboardNameSheet(
                nameDraft: $nameDraft,
                productName: keyboard.productName,
                onSave: {
                    model.setPhysicalKeyboardName(keyboard.id, customName: nameDraft)
                    keyboardToRename = nil
                },
                onCancel: { keyboardToRename = nil }
            )
        }
    }

    private var hasPersistenceError: Bool {
        model.persistenceError != nil || model.activityTriggeredSwitching.persistenceError != nil
    }

    private func presentRename(for keyboard: PhysicalKeyboard) {
        nameDraft = keyboard.customName ?? ""
        keyboardToRename = keyboard
    }

    private func excludedName(
        _ exclusion: SavedPhysicalKeyboardExclusion,
        savedRecord: OnboardingPhysicalKeyboardRow.SavedRecordSelection
    ) -> String {
        if case let .matched(record) = savedRecord { return record.name }
        return exclusion.name
    }

    private func unsupportedReason(for keyboard: PhysicalKeyboard) -> String {
        guard case let .unsupported(reason) = keyboard.assignmentState else { return "Unsupported" }
        return switch reason {
        case .missingIdentity: "Identity unavailable"
        case .unstableIdentity: "Identity unstable"
        case .sharedIdentity: "Identity shared"
        case .ambiguousIdentity: "Identity ambiguous"
        }
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
