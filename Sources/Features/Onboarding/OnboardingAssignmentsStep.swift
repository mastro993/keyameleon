import SwiftUI

@MainActor
struct OnboardingAssignmentsStep: View {
    let model: KeyameleonSetupModel
    let rows: [PhysicalKeyboardRow]
    let onIgnore: (PhysicalKeyboardRecordID) -> Void
    let onStopIgnoring: (String) -> Void

    static let switchingNote = "Switching follows keyboard activity. "
        + "Initial key presses may still use the previous Input Source."

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("An Input Source for every keyboard.")
                .font(.title)
                .bold()
                .foregroundStyle(OnboardingPalette.primary)
            Text("Connect the keyboards you use with this Mac. "
                 + "Turn off devices that aren’t keyboards. "
                 + "They stay in the list, so you can turn them back on any time.")
                .font(.body)
                .lineSpacing(2)
                .padding(.vertical, 1)
                .foregroundStyle(OnboardingPalette.secondary)
            KeyameleonInsetGroup {
                if rows.isEmpty {
                    Text(model.persistenceError == nil
                        ? "Connect a Physical Keyboard to add a Keyboard Assignment."
                        : "Retry to load saved Physical Keyboards.")
                        .foregroundStyle(OnboardingPalette.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                }
                ForEach(rows) { row in
                    PhysicalKeyboardRowView(
                        row: row,
                        model: model,
                        rowPadding: KeyameleonTheme.Metrics.onboardingKeyboardRowPadding,
                        onIgnore: onIgnore,
                        onStopIgnoring: onStopIgnoring
                    )
                    .keyameleonGroupSeparator(
                        row.id != rows.first?.id,
                        inset: KeyameleonTheme.Metrics.onboardingKeyboardRowPadding.leading
                    )
                }
            }
            Text(Self.switchingNote)
                .font(.callout)
                .foregroundStyle(OnboardingPalette.muted)
        }
    }
}

#if DEBUG
#Preview("Assignment table") {
    let fixture = KeyameleonPreviewFixtures.setup(.assignmentsPopulated)
    OnboardingAssignmentsStep(
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
    .frame(width: 630)
}
#endif
