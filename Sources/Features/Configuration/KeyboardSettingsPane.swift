import SwiftUI

/// The Keyboards pane: one row per Physical Keyboard, ignored ones included.
@MainActor
struct KeyboardSettingsPane: View {
    private let model: SetupModel
    @State private var rows: PhysicalKeyboardRows

    init(model: SetupModel) {
        self.model = model
        _rows = State(initialValue: PhysicalKeyboardRows(
            physicalKeyboards: model.physicalKeyboards,
            exclusions: model.excludedPhysicalKeyboards,
            savedRecords: model.savedPhysicalKeyboardRecords,
            exclusionKeyFor: model.exclusionKey(for:)
        ))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.paneSpacing) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Keyboard layouts")
                    .font(Theme.Typography.sectionTitle)
                    .foregroundStyle(Theme.primary)
                Text("Choose a layout for each keyboard. Keyameleon switches when you type.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.secondary)
            }

            if rows.rows.isEmpty {
                if !model.hasPersistenceFailure {
                    KeyboardEmptyState()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Metrics.paneSpacing) {
                        keyboardGroup
                        Text(
                            "New keyboards appear here when connected. "
                                + "Disconnected keyboards keep their saved layout."
                        )
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.secondary)
                    }
                    .padding(.bottom, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(Theme.Metrics.panePadding)
        .accessibilityIdentifier("physical-keyboard-configuration")
        .onChange(of: model.physicalKeyboards) { _, _ in rows.reconcile(with: model) }
        .onChange(of: model.excludedPhysicalKeyboards) { _, _ in rows.reconcile(with: model) }
        .onChange(of: model.savedPhysicalKeyboardRecords) { _, _ in rows.reconcile(with: model) }
    }

    private var keyboardGroup: some View {
        InsetGroup {
            ForEach(rows.rows) { row in
                PhysicalKeyboardRowView(
                    row: row,
                    model: model,
                    rowPadding: Theme.Metrics.settingsKeyboardRowPadding,
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
                    inset: Theme.Metrics.settingsKeyboardRowPadding.leading
                )
            }
        }
    }
}

/// The Keyboards pane empty state: nothing is connected yet.
@MainActor
private struct KeyboardEmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "keyboard")
                .font(.largeTitle)
                .foregroundStyle(Theme.secondary)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("No keyboards detected")
                    .font(Theme.Typography.emptyStateTitle)
                    .foregroundStyle(Theme.primary)
                Text(
                    """
                    Plug in a USB keyboard or connect one via Bluetooth.
                    Your keyboard will appear here when detected.
                    """
                )
                .font(Theme.Typography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Keyboards pane") {
    KeyboardSettingsPane(model: PreviewFixtures.setup(.pencilAssignments).model)
        .frame(width: 620, height: 560)
        .background(Theme.contentBackground)
}

#Preview("Keyboards pane empty") {
    KeyboardSettingsPane(model: PreviewFixtures.setup(.assignmentsEmpty).model)
        .frame(width: 620, height: 560)
        .background(Theme.contentBackground)
        .preferredColorScheme(.dark)
}
#endif
