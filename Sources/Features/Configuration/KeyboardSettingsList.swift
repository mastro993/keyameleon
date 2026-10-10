import SwiftUI

@MainActor
struct KeyboardSettingsList: View {
    let model: SetupModel
    let rows: [PhysicalKeyboardRow]
    let unsupportedKeyboards: [PhysicalKeyboard]
    let onIgnore: (PhysicalKeyboardRecordID) -> Void
    let onStopIgnoring: (String) -> Void

    var body: some View {
        Form {
            Section {
                if rows.isEmpty {
                    Text("No supported keyboards connected.")
                        .foregroundStyle(.secondary)
                }
                ForEach(rows) { row in
                    PhysicalKeyboardRowView(
                        row: row,
                        model: model,
                        onIgnore: onIgnore,
                        onStopIgnoring: onStopIgnoring
                    )
                }
            } header: {
                Text("Input sources")
            } footer: {
                Text(
                    "Keyameleon switches to a keyboard’s input source when you type on it. "
                        + "New keyboards appear when connected. Disconnected ones keep their input source."
                )
            }

            UnsupportedPhysicalKeyboardsSection(keyboards: unsupportedKeyboards)
        }
        .formStyle(.grouped)
    }
}

#if DEBUG
#Preview("Keyboard settings list") {
    let fixture = PreviewFixtures.setup(.pencilAssignments)
    let rows = PhysicalKeyboardRows(
        physicalKeyboards: fixture.model.physicalKeyboards,
        exclusions: fixture.model.excludedPhysicalKeyboards,
        savedRecords: fixture.model.savedPhysicalKeyboardRecords,
        exclusionKeyFor: fixture.model.exclusionKey(for:)
    )
    KeyboardSettingsList(
        model: fixture.model,
        rows: rows.rows,
        unsupportedKeyboards: rows.unsupportedKeyboards + [PreviewFixtures.unsupportedPhysicalKeyboard()],
        onIgnore: { _ in },
        onStopIgnoring: { _ in }
    )
    .frame(width: 620, height: 420)
}
#endif
