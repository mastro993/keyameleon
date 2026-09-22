import SwiftUI

@MainActor
struct KeyameleonRootView: View {
    private let model: KeyameleonSetupModel
    private let switching: ActivityTriggeredSwitching

    init(
        model: KeyameleonSetupModel,
        switching: ActivityTriggeredSwitching
    ) {
        self.model = model
        self.switching = switching
    }

    var body: some View {
        Group {
            if model.isSetupComplete {
                VStack(spacing: 12) {
                    Text("Keyameleon")
                        .font(.title.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text("Guided setup is complete. Keyameleon stays in the menu bar.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("guided-setup")
            } else {
                ScrollView {
                    KeyameleonOnboardingView(model: model, switching: switching)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 520)
    }
}

#if DEBUG
#Preview("Guided setup complete") {
    let fixture = KeyameleonPreviewFixtures.setup(.completed)
    KeyameleonRootView(model: fixture.model, switching: fixture.switching)
}

#Preview("Permission required") {
    let fixture = KeyameleonPreviewFixtures.setup(.permissionRequired)
    KeyameleonRootView(model: fixture.model, switching: fixture.switching)
}

#Preview("Assignments populated") {
    let fixture = KeyameleonPreviewFixtures.setup(.assignmentsPopulated)
    KeyameleonRootView(model: fixture.model, switching: fixture.switching)
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .xxxLarge)
}
#endif
