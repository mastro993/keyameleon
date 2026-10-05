import SwiftUI

/// The Keyboards pane: one row per Physical Keyboard, ignored ones included.
@MainActor
struct KeyameleonKeyboardSettingsPane: View {
    private let model: KeyameleonSetupModel
    @State private var rows: PhysicalKeyboardRows

    init(model: KeyameleonSetupModel) {
        self.model = model
        _rows = State(initialValue: PhysicalKeyboardRows(
            physicalKeyboards: model.physicalKeyboards,
            exclusions: model.excludedPhysicalKeyboards,
            savedRecords: model.savedPhysicalKeyboardRecords,
            exclusionKeyFor: model.exclusionKey(for:)
        ))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KeyameleonTheme.Metrics.paneSpacing) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Keyboard layouts")
                    .font(.headline)
                    .bold()
                    .foregroundStyle(KeyameleonTheme.primary)
                Text("Choose a layout for each keyboard. Keyameleon switches when you type.")
                    .font(.callout)
                    .foregroundStyle(KeyameleonTheme.secondary)
            }

            if rows.rows.isEmpty {
                if model.persistenceError == nil {
                    KeyameleonKeyboardEmptyState()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: KeyameleonTheme.Metrics.paneSpacing) {
                        keyboardGroup
                        Text(
                            "New keyboards appear here when connected. "
                                + "Disconnected keyboards keep their saved layout."
                        )
                        .font(.callout)
                        .foregroundStyle(KeyameleonTheme.secondary)
                    }
                    .padding(.bottom, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(KeyameleonTheme.Metrics.panePadding)
        .accessibilityIdentifier("physical-keyboard-configuration")
        .onChange(of: model.physicalKeyboards) { _, _ in rows.reconcile(with: model) }
        .onChange(of: model.excludedPhysicalKeyboards) { _, _ in rows.reconcile(with: model) }
        .onChange(of: model.savedPhysicalKeyboardRecords) { _, _ in rows.reconcile(with: model) }
    }

    private var keyboardGroup: some View {
        KeyameleonInsetGroup {
            ForEach(rows.rows) { row in
                PhysicalKeyboardRowView(
                    row: row,
                    model: model,
                    rowPadding: KeyameleonTheme.Metrics.settingsKeyboardRowPadding,
                    onIgnore: { id in
                        model.excludePhysicalKeyboard(id)
                        rows.reconcile(with: model)
                    },
                    onStopIgnoring: { key in
                        model.restorePhysicalKeyboard(exclusionKey: key)
                        rows.reconcile(with: model)
                    }
                )
                .keyameleonGroupSeparator(
                    row.id != rows.rows.first?.id,
                    inset: KeyameleonTheme.Metrics.settingsKeyboardRowPadding.leading
                )
            }
        }
    }
}

/// The Keyboards pane empty state: nothing is connected yet.
@MainActor
private struct KeyameleonKeyboardEmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "keyboard")
                .font(.largeTitle)
                .foregroundStyle(KeyameleonTheme.secondary)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("No keyboards detected")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(KeyameleonTheme.primary)
                Text(
                    """
                    Plug in a USB keyboard or connect one via Bluetooth.
                    Your keyboard will appear here when detected.
                    """
                )
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(KeyameleonTheme.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Keyboards pane") {
    KeyameleonKeyboardSettingsPane(model: KeyameleonPreviewFixtures.setup(.pencilAssignments).model)
        .frame(width: 620, height: 560)
        .background(KeyameleonTheme.contentBackground)
}

#Preview("Keyboards pane empty") {
    KeyameleonKeyboardSettingsPane(model: KeyameleonPreviewFixtures.setup(.assignmentsEmpty).model)
        .frame(width: 620, height: 560)
        .background(KeyameleonTheme.contentBackground)
        .preferredColorScheme(.dark)
}
#endif
