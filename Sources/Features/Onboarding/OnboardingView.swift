import SwiftUI

@MainActor
struct OnboardingView: View {
    private let model: SetupModel
    private let switching: ActivityTriggeredSwitching
    @State private var keyboardRows: PhysicalKeyboardRows

    init(model: SetupModel, switching: ActivityTriggeredSwitching) {
        self.model = model
        self.switching = switching
        _keyboardRows = State(initialValue: PhysicalKeyboardRows(
            physicalKeyboards: model.physicalKeyboards,
            exclusions: model.excludedPhysicalKeyboards,
            savedRecords: model.savedPhysicalKeyboardRecords,
            exclusionKeyFor: model.exclusionKey(for:)
        ))
    }

    var body: some View {
        HStack(spacing: 0) {
            OnboardingSidebar(step: model.guidedSetupStep, hasAssignments: includedAssignmentCount > 0)
            VStack(spacing: 0) {
                switch model.guidedSetupStep {
                case .permission:
                    OnboardingScrollingStage(model: model, spacing: 28) {
                        OnboardingPermissionStep()
                    }
                case .assignments:
                    OnboardingAssignmentsStep(
                        model: model,
                        rows: keyboardRows.rows,
                        unsupportedKeyboards: keyboardRows.unsupportedKeyboards,
                        onIgnore: { id in
                            model.excludePhysicalKeyboard(id)
                            reconcileKeyboardRows()
                        },
                        onStopIgnoring: { key in
                            model.restorePhysicalKeyboard(exclusionKey: key)
                            reconcileKeyboardRows()
                        }
                    )
                case .ready:
                    OnboardingScrollingStage(model: model, spacing: 16) {
                        OnboardingReadyStep(
                            assignmentCount: includedAssignmentCount,
                            switchingStatus: switching.outcome.switchingStatus
                        )
                    }
                }
                OnboardingFooter(model: model)
            }
            .background(OnboardingPalette.background)
        }
        .frame(minWidth: 840, minHeight: 640)
        .ignoresSafeArea(edges: .top)
        .accessibilityIdentifier("guided-setup")
        .onChange(of: model.physicalKeyboards) { _, _ in reconcileKeyboardRows() }
        .onChange(of: model.excludedPhysicalKeyboards) { _, _ in reconcileKeyboardRows() }
        .onChange(of: model.savedPhysicalKeyboardRecords) { _, _ in reconcileKeyboardRows() }
    }

    private var includedAssignmentCount: Int {
        model.physicalKeyboards.filter { keyboard in
            keyboard.isAssignable && keyboard.keyboardAssignment != nil
        }.count
    }

    private func reconcileKeyboardRows() {
        keyboardRows.reconcile(with: model)
    }
}

#if DEBUG
#Preview("Permissions") {
    let fixture = PreviewFixtures.setup(.permissionRequired)
    OnboardingView(model: fixture.model, switching: fixture.switching)
        .frame(width: 1000, height: 750)
}

#Preview("Keyboards") {
    let fixture = PreviewFixtures.setup(.pencilAssignments)
    OnboardingView(model: fixture.model, switching: fixture.switching)
        .frame(width: 1000, height: 750)
}

#Preview("Keyboards mixed and unsupported") {
    let fixture = PreviewFixtures.setup(.mixedAssignments)
    OnboardingView(model: fixture.model, switching: fixture.switching)
        .frame(width: 1000, height: 750)
        .preferredColorScheme(.dark)
}

#Preview("Ready") {
    let fixture = PreviewFixtures.setup(.readyPopulated)
    OnboardingView(model: fixture.model, switching: fixture.switching)
        .frame(width: 1000, height: 750)
}

#Preview("Keyboards minimum size and large text") {
    let fixture = PreviewFixtures.setup(.manyAssignments)
    OnboardingView(model: fixture.model, switching: fixture.switching)
        .frame(width: 840, height: 640)
        .environment(\.dynamicTypeSize, .xxxLarge)
}

#Preview("Keyboards all excluded") {
    let fixture = PreviewFixtures.setupWithAllKeyboardsExcluded()
    OnboardingView(model: fixture.model, switching: fixture.switching)
        .frame(width: 1000, height: 750)
}
#endif

#if DEBUG
#Preview("Keyboards persistence failure") {
    let fixture = PreviewFixtures.setup(.persistenceFailure)
    RootView(model: fixture.model, switching: fixture.switching)
        .frame(width: 840, height: 640)
}

#Preview("Permission recovery minimum size") {
    let fixture = PreviewFixtures.setup(.permissionDenied)
    RootView(model: fixture.model, switching: fixture.switching)
        .frame(width: 840, height: 640)
}

#Preview("Ready while switching is paused") {
    let fixture = PreviewFixtures.setup(.readyPaused)
    RootView(model: fixture.model, switching: fixture.switching)
        .frame(width: 1000, height: 750)
}
#endif
