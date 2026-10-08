import SwiftUI

@MainActor
struct OnboardingAssignmentsHeader: View {
    let model: SetupModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PersistenceFailureNotice(model: model)
            OnboardingProgress(step: model.guidedSetupStep)
            Text("An input source for every keyboard.")
                .font(.title)
                .bold()
                .foregroundStyle(OnboardingPalette.primary)
            Text("Pick an input source for each keyboard. Not a keyboard? Choose Ignore from its ⋯ menu.")
                .font(.body)
                .lineSpacing(2)
                .padding(.vertical, 1)
                .foregroundStyle(OnboardingPalette.secondary)
        }
        .textCase(nil)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview("Onboarding assignments header") {
    OnboardingAssignmentsHeader(model: PreviewFixtures.setup(.assignmentsPopulated).model)
        .padding(37)
        .frame(width: 705)
        .background(OnboardingPalette.background)
}
#endif
