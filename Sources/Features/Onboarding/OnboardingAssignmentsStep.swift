import SwiftUI

@MainActor
struct OnboardingAssignmentsStep: View {
    let model: KeyameleonSetupModel
    let rows: [OnboardingPhysicalKeyboardRow]
    let onExclude: (PhysicalKeyboardRecordID) -> Void
    let onIncludeAgain: (String) -> Void

    static let switchingNote = "Switching follows keyboard activity. "
        + "Initial key presses may still use the previous Input Source."

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("An Input Source for every keyboard.")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(OnboardingPalette.primary)
            Text("Connect the keyboards you use with this Mac. You can finish assigning them later in Settings.")
                .font(.title2)
                .foregroundStyle(OnboardingPalette.secondary)
            HStack {
                Text("Physical Keyboard")
                Spacer()
                Text("Input Source")
                    .frame(width: 176, alignment: .leading)
            }
            .font(.title3)
            .foregroundStyle(OnboardingPalette.muted)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            VStack(spacing: 0) {
                if rows.isEmpty {
                    Text(model.persistenceError == nil
                        ? "Connect a Physical Keyboard to add a Keyboard Assignment."
                        : "Retry to load saved Physical Keyboards.")
                        .foregroundStyle(OnboardingPalette.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                }
                ForEach(rows) { row in
                    OnboardingKeyboardRow(
                        row: row,
                        model: model,
                        onExclude: onExclude,
                        onIncludeAgain: onIncludeAgain
                    )
                    .overlay(alignment: .top) {
                        if row.id != rows.first?.id {
                            OnboardingPalette.border.frame(height: 1)
                        }
                    }
                }
            }
            .background(OnboardingPalette.background, in: .rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(OnboardingPalette.border) }
            Text(Self.switchingNote)
                .font(.title2)
                .foregroundStyle(OnboardingPalette.muted)
        }
    }
}

#if DEBUG
#Preview("Assignment table") {
    let fixture = KeyameleonPreviewFixtures.setup(.assignmentsPopulated)
    OnboardingAssignmentsStep(
        model: fixture.model,
        rows: OnboardingPhysicalKeyboardRows(
            physicalKeyboards: fixture.model.physicalKeyboards,
            exclusions: fixture.model.excludedPhysicalKeyboards,
            exclusionKeyFor: fixture.model.exclusionKey(for:)
        ).rows,
        onExclude: { _ in },
        onIncludeAgain: { _ in }
    )
    .frame(width: 630)
}
#endif
