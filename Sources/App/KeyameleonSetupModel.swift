import Foundation
import Combine

@MainActor
protocol SetupDecisionStoring: AnyObject {
    var hasStartedGuidedSetup: Bool { get }
    var hasCompletedGuidedSetup: Bool { get }

    func markGuidedSetupStarted()
    func markGuidedSetupCompleted()
}

@MainActor
final class UserDefaultsSetupDecisionStore: SetupDecisionStoring {
    private enum Key {
        static let hasStartedGuidedSetup = "keyameleon.guidedSetup.started"
        static let hasCompletedGuidedSetup = "keyameleon.guidedSetup.completed"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasStartedGuidedSetup: Bool {
        defaults.bool(forKey: Key.hasStartedGuidedSetup)
    }

    var hasCompletedGuidedSetup: Bool {
        defaults.bool(forKey: Key.hasCompletedGuidedSetup)
    }

    func markGuidedSetupStarted() {
        defaults.set(true, forKey: Key.hasStartedGuidedSetup)
    }

    func markGuidedSetupCompleted() {
        defaults.set(true, forKey: Key.hasCompletedGuidedSetup)
    }

    func resetForUITesting() {
        defaults.removeObject(forKey: Key.hasStartedGuidedSetup)
        defaults.removeObject(forKey: Key.hasCompletedGuidedSetup)
    }
}

@MainActor
final class KeyameleonSetupModel: ObservableObject {
    @Published private(set) var switchingStatus: SwitchingStatus
    @Published private(set) var isSetupComplete: Bool
    @Published private(set) var hasStartedGuidedSetup: Bool
    @Published private(set) var physicalKeyboards: [PhysicalKeyboard] = []
    @Published private(set) var eligibleInputSources: [EligibleInputSource] = []

    private let permissionProvider: any ListenPermissionProviding
    private let setupStore: any SetupDecisionStoring
    private let systemSettingsOpener: any SystemSettingsOpening
    private let physicalKeyboardDiscoverer: any PhysicalKeyboardDiscovering
    private let inputSourceProvider: any InputSourceProviding
    private var physicalKeyboardCatalog = PhysicalKeyboardCatalog()
    private var isDiscoveryStarted = false

    var onChange: (@MainActor () -> Void)?

    var canObservePhysicalKeyboards: Bool {
        switchingStatus.allowsActivityTriggeredSwitching
    }

    var canRequestInputSources: Bool {
        switchingStatus.allowsActivityTriggeredSwitching
    }

    init(
        permissionProvider: any ListenPermissionProviding,
        setupStore: any SetupDecisionStoring,
        systemSettingsOpener: any SystemSettingsOpening,
        physicalKeyboardDiscoverer: any PhysicalKeyboardDiscovering = SystemPhysicalKeyboardDiscoverer(),
        inputSourceProvider: any InputSourceProviding = SystemInputSourceProvider()
    ) {
        self.permissionProvider = permissionProvider
        self.setupStore = setupStore
        self.systemSettingsOpener = systemSettingsOpener
        self.physicalKeyboardDiscoverer = physicalKeyboardDiscoverer
        self.inputSourceProvider = inputSourceProvider
        self.switchingStatus = permissionProvider.checkListenPermission().switchingStatus
        self.isSetupComplete = setupStore.hasCompletedGuidedSetup
        self.hasStartedGuidedSetup = setupStore.hasStartedGuidedSetup
    }

    func refreshPermission() {
        let newStatus = permissionProvider.checkListenPermission().switchingStatus
        if switchingStatus != newStatus {
            switchingStatus = newStatus
            onChange?()
        }

        refreshInputSources()
        updatePhysicalKeyboardDiscovery()
    }

    func requestPermission() {
        guard switchingStatus != .ready else {
            return
        }

        _ = permissionProvider.requestListenPermission()
        refreshPermission()
        completeSetup()
    }

    func beginGuidedSetup() {
        guard !hasStartedGuidedSetup else {
            return
        }

        setupStore.markGuidedSetupStarted()
        hasStartedGuidedSetup = true
        onChange?()
    }

    func completeSetup() {
        var changed = false

        if !hasStartedGuidedSetup {
            setupStore.markGuidedSetupStarted()
            hasStartedGuidedSetup = true
            changed = true
        }

        if !isSetupComplete {
            setupStore.markGuidedSetupCompleted()
            isSetupComplete = true
            changed = true
        }

        if changed {
            onChange?()
        }
    }

    func openSystemSettings() {
        systemSettingsOpener.openSystemSettings()
    }

    private func refreshInputSources() {
        let refreshedInputSources = inputSourceProvider.eligibleInputSources()
        guard refreshedInputSources != eligibleInputSources else {
            return
        }

        eligibleInputSources = refreshedInputSources
        onChange?()
    }

    private func updatePhysicalKeyboardDiscovery() {
        guard switchingStatus.allowsActivityTriggeredSwitching else {
            guard isDiscoveryStarted else {
                return
            }

            physicalKeyboardDiscoverer.stop()
            isDiscoveryStarted = false
            physicalKeyboardCatalog = PhysicalKeyboardCatalog()
            physicalKeyboards = []
            onChange?()
            return
        }

        guard !isDiscoveryStarted else {
            return
        }

        isDiscoveryStarted = true
        physicalKeyboardDiscoverer.start { [weak self] change in
            self?.apply(change)
        }
    }

    private func apply(_ change: PhysicalKeyboardDiscoveryChange) {
        guard switchingStatus.allowsActivityTriggeredSwitching else {
            return
        }

        physicalKeyboardCatalog.apply(change)
        physicalKeyboards = physicalKeyboardCatalog.physicalKeyboards
        onChange?()
    }
}
