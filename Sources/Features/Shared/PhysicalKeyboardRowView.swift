import SwiftUI

/// One Physical Keyboard row, shared by Guided setup and Settings.
///
/// The row draws the name and connection status, the native Input Source
/// picker, and the keyboard's actions menu. Ignoring and restoring write
/// straight through the model, so both flows behave the same way.
@MainActor
struct PhysicalKeyboardRowView: View {
    let row: PhysicalKeyboardRow
    let model: SetupModel
    /// The flow owns the row's inset: Settings packs its group tighter than Guided setup.
    let rowPadding: EdgeInsets
    let onIgnore: (PhysicalKeyboardRecordID) -> Void
    let onStopIgnoring: (String) -> Void

    @State private var keyboardToRename: PhysicalKeyboard?
    @State private var nameDraft = ""

    var body: some View {
        HStack(spacing: 16) {
            switch row.state {
            case let .included(keyboard):
                includedLabels(for: keyboard)
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    if keyboard.isAssignable {
                        assignmentPicker(for: keyboard)
                    } else {
                        Text("Unsupported")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondary)
                            .frame(width: 176, alignment: .leading)
                            .help(unsupportedReason(for: keyboard))
                            .accessibilityValue(unsupportedReason(for: keyboard))
                    }
                    if model.canExcludePhysicalKeyboard(keyboard.id) {
                        actionsMenu(for: keyboard)
                    } else {
                        menuColumnSpacer
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            case let .excluded(exclusion, savedRecord):
                excludedLabels(for: exclusion, savedRecord: savedRecord)
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    switch savedRecord {
                    case let .matched(record):
                        savedAssignmentPicker(for: record)
                    case .missing, .ambiguous:
                        Text("Assignment unavailable")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
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
                        Button("Stop ignoring", systemImage: "eye") {
                            onStopIgnoring(exclusion.key)
                        }
                    } label: {
                        menuLabel
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
        .padding(rowPadding)
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

    private func includedLabels(for keyboard: PhysicalKeyboard) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(keyboard.name)
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.primary)
            Text(row.subtitle(connectedExcludedKeys: model.connectedExcludedKeyboardKeys))
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
    }

    private func excludedLabels(
        for exclusion: SavedPhysicalKeyboardExclusion,
        savedRecord: PhysicalKeyboardRow.SavedRecordSelection
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(excludedName(exclusion, savedRecord: savedRecord))
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.muted)
            Text(row.subtitle(connectedExcludedKeys: model.connectedExcludedKeyboardKeys))
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
    }

    private func assignmentPicker(for keyboard: PhysicalKeyboard) -> some View {
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
    }

    /// An ignored keyboard keeps its saved assignment on screen, read-only.
    private func savedAssignmentPicker(for record: SavedPhysicalKeyboardRecord) -> some View {
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
    }

    private func actionsMenu(for keyboard: PhysicalKeyboard) -> some View {
        Menu {
            if keyboard.isAssignable && keyboard.id.isIdentityBased {
                Button("Rename…", systemImage: "pencil") {
                    presentRename(for: keyboard)
                }
            }
            Button("Ignore", systemImage: "eye.slash") {
                onIgnore(keyboard.id)
            }
        } label: {
            menuLabel
        }
        .font(.body)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 28)
        .disabled(hasPersistenceError)
        .accessibilityIdentifier("keyboard-actions")
    }

    private var menuLabel: some View {
        Label("Keyboard actions", systemImage: "ellipsis")
            .labelStyle(.iconOnly)
            .frame(width: 28, height: 28)
    }

    /// The built-in keyboard reserves the actions column without offering actions.
    private var menuColumnSpacer: some View {
        Color.clear
            .frame(width: 28, height: 28)
            .accessibilityHidden(true)
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
        savedRecord: PhysicalKeyboardRow.SavedRecordSelection
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
#Preview("Physical keyboard row included") {
    let fixture = PreviewFixtures.setup(.pencilAssignments)
    if let keyboard = fixture.model.physicalKeyboards.first(where: { $0.isAssignable }) {
        PhysicalKeyboardRowView(
            row: PhysicalKeyboardRow(physicalKeyboard: keyboard, exclusionKey: nil),
            model: fixture.model,
            rowPadding: Theme.Metrics.onboardingKeyboardRowPadding,
            onIgnore: { _ in },
            onStopIgnoring: { _ in }
        )
        .frame(width: 630)
    }
}

#Preview("Physical keyboard row ignored") {
    let fixture = PreviewFixtures.setup(.excludedDevices)
    if let exclusion = fixture.model.excludedPhysicalKeyboards.first {
        PhysicalKeyboardRowView(
            row: PhysicalKeyboardRow(exclusion: exclusion, savedRecord: .missing),
            model: fixture.model,
            rowPadding: Theme.Metrics.settingsKeyboardRowPadding,
            onIgnore: { _ in },
            onStopIgnoring: { _ in }
        )
        .frame(width: 630)
        .preferredColorScheme(.dark)
    }
}
#endif
