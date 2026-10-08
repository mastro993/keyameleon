import SwiftUI

@MainActor
struct RootView: View {
    private let model: SetupModel
    private let switching: ActivityTriggeredSwitching

    init(
        model: SetupModel,
        switching: ActivityTriggeredSwitching
    ) {
        self.model = model
        self.switching = switching
    }

    var body: some View {
        Group {
            if model.isSetupComplete {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 32.0, height: 32.0)
                        .foregroundStyle(.green)
                    Text("Keyameleon is ready")
                        .font(.title.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text("Setup is complete. Keyameleon runs in the menu bar.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("guided-setup")
                .safeAreaInset(edge: .top) { PersistenceFailureNotice(model: model) }
            } else {
                OnboardingView(model: model, switching: switching)
            }
        }
        .frame(minWidth: 840, minHeight: 640)
        .ignoresSafeArea(edges: .top)
    }
}

#if DEBUG
#Preview("Guided setup complete") {
    let fixture = PreviewFixtures.setup(.completed)
    RootView(model: fixture.model, switching: fixture.switching)
}

#Preview("Permission required") {
    let fixture = PreviewFixtures.setup(.permissionRequired)
    RootView(model: fixture.model, switching: fixture.switching)
}

#Preview("Assignments populated") {
    let fixture = PreviewFixtures.setup(.assignmentsPopulated)
    RootView(model: fixture.model, switching: fixture.switching)
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .xxxLarge)
}
#endif
