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
                        .foregroundStyle(Theme.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowBackground(Theme.windowBackground)
                }
                ForEach(rows) { row in
                    PhysicalKeyboardRowView(
                        row: row,
                        model: model,
                        rowPadding: EdgeInsets(),
                        onIgnore: onIgnore,
                        onStopIgnoring: onStopIgnoring
                    )
                    .listRowBackground(Theme.windowBackground)
                }
            } header: {
                KeyboardSettingsHeader()
            } footer: {
                Text(
                    "New keyboards appear here when connected. "
                        + "Disconnected keyboards keep their saved layout."
                )
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            UnsupportedPhysicalKeyboardsSection(keyboards: unsupportedKeyboards)
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
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
    .background(Theme.contentBackground)
}
#endif
