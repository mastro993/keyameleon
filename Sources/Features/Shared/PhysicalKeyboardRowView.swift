import SwiftUI

/// One Physical Keyboard row, shared by Guided setup and Settings.
///
/// The row is a native Input Source picker labelled with the name and
/// connection status, followed by the keyboard's actions menu. Unsupported keyboards never
/// get a row; `UnsupportedPhysicalKeyboardsSection` lists them. Ignoring and restoring write
/// straight through the model, so both flows behave the same way.
@MainActor
struct PhysicalKeyboardRowView: View {
    let row: PhysicalKeyboardRow
    let model: SetupModel
    let onIgnore: (PhysicalKeyboardRecordID) -> Void
    let onStopIgnoring: (String) -> Void

    @State private var keyboardToRename: PhysicalKeyboard?
    @State private var nameDraft = ""

    var body: some View {
        HStack {
            switch row.state {
            case let .included(keyboard):
                InputSourcePicker(
                    selection: Binding(
                        get: { keyboard.keyboardAssignment?.inputSourceIdentifier },
                        set: { model.setKeyboardAssignment(keyboard.id, inputSourceIdentifier: $0) }
                    ),
                    inputSources: model.eligibleInputSources
                ) {
                    Text(keyboard.name)
                    Text(subtitle)
                }
                .disabled(model.eligibleInputSources.isEmpty || hasPersistenceError)
                let menu = actionsMenu {
                    if keyboard.id.isIdentityBased {
                        Button("Rename…", systemImage: "pencil") { presentRename(for: keyboard) }
                    }
                    Button("Ignore", systemImage: "eye.slash") { onIgnore(keyboard.id) }
                }
                if model.canExcludePhysicalKeyboard(keyboard.id) {
                    menu
                } else {
                    // The built-in keyboard has no actions but keeps the column so pickers line up.
                    menu.hidden().accessibilityHidden(true)
                }
            case let .excluded(exclusion, savedRecord):
                InputSourcePicker(
                    selection: .constant(savedRecord.record?.keyboardAssignment?.inputSourceIdentifier),
                    inputSources: model.eligibleInputSources
                ) {
                    Text(savedRecord.record?.name ?? exclusion.name)
                    Text(subtitle)
                }
                .disabled(true)
                .help("Ignored devices never switch the input source. Use the actions menu to stop ignoring.")
                actionsMenu {
                    if let record = savedRecord.record, record.recordID.isIdentityBased, !record.isBuiltInIdentity {
                        Button("Rename…", systemImage: "pencil") { presentRename(for: .restored(from: record)) }
                    }
                    Button("Stop Ignoring", systemImage: "eye") { onStopIgnoring(exclusion.key) }
                }
            }
        }
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

    private var subtitle: String {
        row.subtitle(connectedExcludedKeys: model.connectedExcludedKeyboardKeys)
    }

    private func actionsMenu<Items: View>(@ViewBuilder items: () -> Items) -> some View {
        Menu(content: items) {
            Label("Keyboard actions", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Keyboard actions")
        .disabled(hasPersistenceError)
        .accessibilityIdentifier("keyboard-actions")
    }

    private var hasPersistenceError: Bool {
        model.hasPersistenceFailure
    }

    private func presentRename(for keyboard: PhysicalKeyboard) {
        nameDraft = keyboard.customName ?? ""
        keyboardToRename = keyboard
    }
}

#if DEBUG

#Preview("Physical keyboard row included") {
    let fixture = PreviewFixtures.setup(.pencilAssignments)
    if let keyboard = fixture.model.physicalKeyboards.first(where: { $0.isAssignable }) {
        Form {
            PhysicalKeyboardRowView(
                row: PhysicalKeyboardRow(physicalKeyboard: keyboard, exclusionKey: nil),
                model: fixture.model,
                onIgnore: { _ in },
                onStopIgnoring: { _ in }
            )
        }
        .formStyle(.grouped)
        .frame(width: 630)
    }
}

#Preview("Physical keyboard row ignored") {
    let fixture = PreviewFixtures.setup(.excludedDevices)
    if let exclusion = fixture.model.excludedPhysicalKeyboards.first {
        Form {
            PhysicalKeyboardRowView(
                row: PhysicalKeyboardRow(exclusion: exclusion, savedRecord: .missing),
                model: fixture.model,
                onIgnore: { _ in },
                onStopIgnoring: { _ in }
            )
        }
        .formStyle(.grouped)
        .frame(width: 630)
        .preferredColorScheme(.dark)
    }
}
#endif
