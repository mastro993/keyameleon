import SwiftUI

@MainActor
struct OnboardingAssignmentsStep: View {
    let model: SetupModel
    let rows: [PhysicalKeyboardRow]
    let unsupportedKeyboards: [PhysicalKeyboard]
    let onIgnore: (PhysicalKeyboardRecordID) -> Void
    let onStopIgnoring: (String) -> Void

    static let switchingNote = "Switching starts when you type, so the first keys may use the previous input source."

    var body: some View {
        Form {
            Section {
                if rows.isEmpty {
                    Text(!model.hasPersistenceFailure
                        ? "Connect a keyboard to choose its input source."
                        : "Click Retry to load your saved keyboards.")
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

            UnsupportedPhysicalKeyboardsSection(keyboards: unsupportedKeyboards)
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
    let rows = PhysicalKeyboardRows(
        physicalKeyboards: fixture.model.physicalKeyboards,
        exclusions: fixture.model.excludedPhysicalKeyboards,
        savedRecords: fixture.model.savedPhysicalKeyboardRecords,
        exclusionKeyFor: fixture.model.exclusionKey(for:)
    )
    return OnboardingAssignmentsStep(
        model: fixture.model,
        rows: rows.rows,
        unsupportedKeyboards: rows.unsupportedKeyboards,
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
