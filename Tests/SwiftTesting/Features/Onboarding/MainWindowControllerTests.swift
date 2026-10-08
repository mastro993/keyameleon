import Testing
@testable import Keyameleon

@Test("Main window drags only from its title bar")
@MainActor
func mainWindowDragsOnlyFromTitleBar() throws {
    let model = SetupModel(
        permissionProvider: SetupModelTestListenPermissionProvider(state: .granted),
        setupStore: SetupModelTestSetupDecisionStore(),
        inputMonitoringRecovery: SetupModelTestInputMonitoringRecovery()
    )
    let controller = MainWindowController(model: model, switching: model.activityTriggeredSwitching)
    let window = try #require(controller.window)

    #expect(!window.isMovableByWindowBackground)
}
