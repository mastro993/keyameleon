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
        Group {
            if rows.rows.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Metrics.paneSpacing) {
                    KeyboardSettingsHeader()

                    if !model.hasPersistenceFailure {
                        KeyboardEmptyState()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(EdgeInsets(top: 20, leading: 30, bottom: 20, trailing: 30))
            } else {
                KeyboardSettingsList(
                    model: model,
                    rows: rows.rows,
                    onIgnore: { id in
                        model.excludePhysicalKeyboard(id)
                        rows.reconcile(with: model)
                    },
                    onStopIgnoring: { key in
                        model.restorePhysicalKeyboard(exclusionKey: key)
                        rows.reconcile(with: model)
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("physical-keyboard-configuration")
        .onChange(of: model.physicalKeyboards) { _, _ in rows.reconcile(with: model) }
        .onChange(of: model.excludedPhysicalKeyboards) { _, _ in rows.reconcile(with: model) }
        .onChange(of: model.savedPhysicalKeyboardRecords) { _, _ in rows.reconcile(with: model) }
    }
}

/// The Keyboards pane empty state: nothing is connected yet.
@MainActor
private struct KeyboardEmptyState: View {
    var body: some View {
        ContentUnavailableView {
            Label("No keyboards detected", systemImage: "keyboard")
        } description: {
            Text(
                """
                Plug in a USB keyboard or connect one via Bluetooth.
                Your keyboard will appear here when detected.
                """
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

#Preview("Keyboards pane large text") {
    KeyboardSettingsPane(model: PreviewFixtures.setup(.manyAssignments).model)
        .frame(width: 620, height: 560)
        .background(Theme.contentBackground)
        .environment(\.dynamicTypeSize, .xxxLarge)
}

#Preview("Keyboards pane ignored and unavailable") {
    KeyboardSettingsPane(model: PreviewFixtures.setup(.mixedAssignments).model)
        .frame(width: 620, height: 560)
        .background(Theme.contentBackground)
}

#Preview("Keyboards pane persistence failure") {
    KeyboardSettingsPane(model: PreviewFixtures.setup(.persistenceFailure).model)
        .frame(width: 620, height: 560)
        .background(Theme.contentBackground)
}
#endif
