import SwiftUI

@MainActor
struct KeyboardSettingsList: View {
    let model: SetupModel
    let rows: [PhysicalKeyboardRow]
    let onIgnore: (PhysicalKeyboardRecordID) -> Void
    let onStopIgnoring: (String) -> Void

    var body: some View {
        Form {
            Section {
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
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

#if DEBUG
#Preview("Keyboard settings list") {
    let fixture = PreviewFixtures.setup(.pencilAssignments)
    KeyboardSettingsList(
        model: fixture.model,
        rows: PhysicalKeyboardRows(
            physicalKeyboards: fixture.model.physicalKeyboards,
            exclusions: fixture.model.excludedPhysicalKeyboards,
            savedRecords: fixture.model.savedPhysicalKeyboardRecords,
            exclusionKeyFor: fixture.model.exclusionKey(for:)
        ).rows,
        onIgnore: { _ in },
        onStopIgnoring: { _ in }
    )
    .frame(width: 620, height: 420)
    .background(Theme.contentBackground)
}
#endif
