import SwiftUI

@MainActor
struct KeyameleonOnboardingView: View {
    private let model: KeyameleonSetupModel
    private let switching: ActivityTriggeredSwitching
    @State private var keyboardRows: OnboardingPhysicalKeyboardRows

    init(model: KeyameleonSetupModel, switching: ActivityTriggeredSwitching) {
        self.model = model
        self.switching = switching
        _keyboardRows = State(initialValue: OnboardingPhysicalKeyboardRows(
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
                ScrollView {
                    VStack(alignment: .leading, spacing: contentSpacing) {
                        PersistenceFailureNotice(model: model)
                        OnboardingProgress(step: model.guidedSetupStep)
                        Group {
                        switch model.guidedSetupStep {
                        case .permission:
                            OnboardingPermissionStep()
                        case .assignments:
                            OnboardingAssignmentsStep(
                                model: model,
                                rows: keyboardRows.rows,
                                onExclude: { id in
                                    model.excludePhysicalKeyboard(id)
                                    reconcileKeyboardRows()
                                },
                                onIncludeAgain: { key in
                                    model.restorePhysicalKeyboard(exclusionKey: key)
                                    reconcileKeyboardRows()
                                }
                            )
                        case .ready:
                            OnboardingReadyStep(
                                assignmentCount: includedAssignmentCount,
                                switchingStatus: switching.outcome.switchingStatus
                            )
                        }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 37)
                    .padding(.top, 34)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.automatic)
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

    private var contentSpacing: CGFloat {
        switch model.guidedSetupStep {
        case .assignments: 20
        case .permission: 28
        case .ready: 16
        }
    }

    private func reconcileKeyboardRows() {
        keyboardRows.reconcile(
            physicalKeyboards: model.physicalKeyboards,
            exclusions: model.excludedPhysicalKeyboards,
            savedRecords: model.savedPhysicalKeyboardRecords,
            exclusionKeyFor: model.exclusionKey(for:)
        )
    }
}

#if DEBUG
#Preview("Permissions light") {
    let fixture = KeyameleonPreviewFixtures.setup(.permissionRequired)
    KeyameleonOnboardingView(model: fixture.model, switching: fixture.switching)
        .frame(width: 1000, height: 750)
}

#Preview("Permissions dark") {
    let fixture = KeyameleonPreviewFixtures.setup(.permissionRequired)
    KeyameleonOnboardingView(model: fixture.model, switching: fixture.switching)
        .frame(width: 1000, height: 750)
        .preferredColorScheme(.dark)
}

#Preview("Keyboards light") {
    let fixture = KeyameleonPreviewFixtures.setup(.pencilAssignments)
    KeyameleonOnboardingView(model: fixture.model, switching: fixture.switching)
        .frame(width: 1000, height: 750)
}

#Preview("Keyboards dark") {
    let fixture = KeyameleonPreviewFixtures.setup(.pencilAssignments)
    KeyameleonOnboardingView(model: fixture.model, switching: fixture.switching)
        .frame(width: 1000, height: 750)
        .preferredColorScheme(.dark)
}

#Preview("Keyboards mixed and unsupported") {
    let fixture = KeyameleonPreviewFixtures.setup(.mixedAssignments)
    KeyameleonOnboardingView(model: fixture.model, switching: fixture.switching)
        .frame(width: 1000, height: 750)
        .preferredColorScheme(.dark)
}

#Preview("Ready light") {
    let fixture = KeyameleonPreviewFixtures.setup(.readyPopulated)
    KeyameleonOnboardingView(model: fixture.model, switching: fixture.switching)
        .frame(width: 1000, height: 750)
}

#Preview("Ready dark") {
    let fixture = KeyameleonPreviewFixtures.setup(.readyEmpty)
    KeyameleonOnboardingView(model: fixture.model, switching: fixture.switching)
        .frame(width: 1000, height: 750)
        .preferredColorScheme(.dark)
}

#Preview("Keyboards minimum size and large text") {
    let fixture = KeyameleonPreviewFixtures.setup(.manyAssignments)
    KeyameleonOnboardingView(model: fixture.model, switching: fixture.switching)
        .frame(width: 840, height: 640)
        .environment(\.dynamicTypeSize, .xxxLarge)
}

#Preview("Keyboards all excluded") {
    let fixture = KeyameleonPreviewFixtures.setupWithAllKeyboardsExcluded()
    KeyameleonOnboardingView(model: fixture.model, switching: fixture.switching)
        .frame(width: 1000, height: 750)
}
#endif

#if DEBUG
#Preview("Keyboards persistence failure") {
    let fixture = KeyameleonPreviewFixtures.setup(.persistenceFailure)
    KeyameleonRootView(model: fixture.model, switching: fixture.switching)
        .frame(width: 840, height: 640)
}

#Preview("Permission recovery minimum size") {
    let fixture = KeyameleonPreviewFixtures.setup(.permissionWaiting)
    KeyameleonRootView(model: fixture.model, switching: fixture.switching)
        .frame(width: 840, height: 640)
}

#Preview("Ready while switching is paused") {
    let fixture = KeyameleonPreviewFixtures.setup(.readyPaused)
    KeyameleonRootView(model: fixture.model, switching: fixture.switching)
        .frame(width: 1000, height: 750)
}
#endif
