import Foundation
import Testing
@testable import Keyameleon

func makeSetupModelHardwareFacts(
    serviceID: UInt64,
    identity: String = "macos.keyboard.shared",
    serialNumber: String? = "keyboard-a"
) -> PhysicalKeyboardHardwareFacts {
    PhysicalKeyboardHardwareFacts(
        serviceID: serviceID,
        identity: PhysicalKeyboardIdentity(
            rawValue: identity,
            isBuiltIn: false,
            serialNumber: serialNumber
        ),
        name: "Test Keyboard",
        transport: .usb,
        isBuiltIn: false,
        vendorID: 500,
        productID: 100,
        modelNumber: "Model",
        serialNumber: serialNumber
    )
}

@MainActor
final class SetupModelTestListenPermissionProvider: ListenPermissionProviding {
    var state: ListenPermissionState
    private let stateAfterRequest: ListenPermissionState
    private(set) var checkCount = 0
    private(set) var requestCount = 0

    init(
        state: ListenPermissionState,
        stateAfterRequest: ListenPermissionState = .granted
    ) {
        self.state = state
        self.stateAfterRequest = stateAfterRequest
    }

    func checkListenPermission() -> ListenPermissionState {
        checkCount += 1
        return state
    }

    func requestListenPermission() -> Bool {
        requestCount += 1
        state = stateAfterRequest
        return state == .granted
    }
}

@MainActor
final class SetupModelTestSetupDecisionStore: SetupDecisionStoring {
    private(set) var hasStartedGuidedSetup = false
    private(set) var hasCompletedGuidedSetup = false
    private(set) var guidedSetupStep: GuidedSetupStep = .permission
    private(set) var isActivityTriggeredSwitchingPaused = false
    private(set) var hasEvaluatedBuiltInIdentityMigration = false
    private(set) var externalChangeResponse: ExternalChangeResponse = .switchBack

    func markGuidedSetupStarted() {
        hasStartedGuidedSetup = true
        if guidedSetupStep == .permission {
            guidedSetupStep = .permission
        }
    }

    func markGuidedSetupStep(_ step: GuidedSetupStep) {
        hasStartedGuidedSetup = true
        guidedSetupStep = step
    }

    func markGuidedSetupCompleted() {
        hasStartedGuidedSetup = true
        hasCompletedGuidedSetup = true
        guidedSetupStep = .ready
    }

    func setActivityTriggeredSwitchingPaused(_ paused: Bool) {
        isActivityTriggeredSwitchingPaused = paused
    }

    func markBuiltInIdentityMigrationEvaluated() {
        hasEvaluatedBuiltInIdentityMigration = true
    }

    func setExternalChangeResponse(_ response: ExternalChangeResponse) {
        externalChangeResponse = response
    }
}

@MainActor
final class SetupModelTestInputMonitoringRecovery: InputMonitoringRecovering {
    private(set) var openCount = 0
    private(set) var relaunchCount = 0

    func openSystemSettings() {
        openCount += 1
    }

    func relaunch() {
        relaunchCount += 1
    }

    func resetStaleGrantAfterRelaunch() async -> Bool { false }
}

@MainActor
final class SetupModelTestPhysicalKeyboardDiscoverer: PhysicalKeyboardDiscovering {
    private var onChange: (@MainActor (PhysicalKeyboardDiscoveryChange) -> Void)?

    func start(onChange: @escaping @MainActor (PhysicalKeyboardDiscoveryChange) -> Void) {
        self.onChange = onChange
    }

    func stop() {
        onChange = nil
    }

    func emit(_ change: PhysicalKeyboardDiscoveryChange) {
        onChange?(change)
    }
}

@MainActor
final class SetupModelTestInputSourceProvider: InputSourceProviding {
    var inputSources: [EligibleInputSource]

    init(inputSources: [EligibleInputSource]) {
        self.inputSources = inputSources
    }

    func eligibleInputSources() -> [EligibleInputSource] {
        inputSources
    }
}
