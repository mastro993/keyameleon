import SwiftUI

@MainActor
struct OnboardingAssignmentsStep: View {
    let model: SetupModel
    let rows: [PhysicalKeyboardRow]
    let onIgnore: (PhysicalKeyboardRecordID) -> Void
    let onStopIgnoring: (String) -> Void

    static let switchingNote = "Switching follows keyboard activity. "
        + "Initial key presses may still use the previous Input Source."

    var body: some View {
        Form {
            Section {
                if rows.isEmpty {
                    Text(!model.hasPersistenceFailure
                        ? "Connect a Physical Keyboard to add a Keyboard Assignment."
                        : "Retry to load saved Physical Keyboards.")
                        .foregroundStyle(OnboardingPalette.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(EdgeInsets(top: 20, leading: 22, bottom: 20, trailing: 22))
                        .listRowBackground(OnboardingPalette.background)
                } else {
                    ForEach(rows) { row in
                        PhysicalKeyboardRowView(
                            row: row,
                            model: model,
                            rowPadding: EdgeInsets(),
                            onIgnore: onIgnore,
                            onStopIgnoring: onStopIgnoring
                        )
                        .listRowInsets(Theme.Metrics.onboardingKeyboardRowPadding)
                        .listRowBackground(OnboardingPalette.background)
                    }
                }
            } header: {
                OnboardingAssignmentsHeader(model: model)
            } footer: {
                Text(Self.switchingNote)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(OnboardingPalette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(
            .all,
            EdgeInsets(top: 34, leading: 37, bottom: 24, trailing: 37),
            for: .scrollContent
        )
    }
}

#if DEBUG
@MainActor
private func onboardingAssignmentsPreview(_ state: PreviewSetupState) -> some View {
    let fixture = PreviewFixtures.setup(state)
    return OnboardingAssignmentsStep(
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
    .frame(width: 705)
}

#Preview("Assignment table") {
    onboardingAssignmentsPreview(.assignmentsPopulated)
}

#Preview("Assignment table empty") {
    onboardingAssignmentsPreview(.assignmentsEmpty)
}

#Preview("Assignment table large text") {
    onboardingAssignmentsPreview(.manyAssignments)
        .environment(\.dynamicTypeSize, .xxxLarge)
}
#endif
