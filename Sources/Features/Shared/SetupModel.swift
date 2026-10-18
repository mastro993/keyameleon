import Foundation
import Observation

/// Presentation model for setup and Physical Keyboard management.
///
/// Activity-Triggered Switching owns switching behavior and exposes one
/// canonical outcome. This model owns guided setup, saved names and
/// Keyboard Assignment editing only.
@MainActor
@Observable
final class SetupModel {
    private(set) var isSetupComplete: Bool
    private(set) var hasStartedGuidedSetup: Bool
    private(set) var guidedSetupStep: GuidedSetupStep
    var physicalKeyboards: [PhysicalKeyboard] = []
    var connectedExcludedKeyboardKeys: Set<String> = []
    var excludedPhysicalKeyboards: [SavedPhysicalKeyboardExclusion] = []
    var savedPhysicalKeyboardRecords: [SavedPhysicalKeyboardRecord] = []
    private(set) var eligibleInputSources: [EligibleInputSource] = []

    var persistenceError: String?
    /// True while either store cannot be read or written, which is what every
    /// surface reports. The row list and the notice must never disagree.
    var hasPersistenceFailure: Bool {
        persistenceError != nil || activityTriggeredSwitching.persistenceError != nil
    }
    let savedPhysicalKeyboardChanges: SavedPhysicalKeyboardChanges

    var onGuidedSetupCompleted: ((GuidedSetupCompletionDestination) -> Void)?

    let activityTriggeredSwitching: ActivityTriggeredSwitching

    let setupStore: any SetupDecisionStoring
    private let inputMonitoringRecovery: any InputMonitoringRecovering
    let physicalKeyboardDiscovery: PhysicalKeyboardDiscovery
    private let inputSources: InputSourceModule
    let physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring
    let exclusionStore: any PhysicalKeyboardExclusionStoring
    let resolver: PhysicalKeyboardPresentationResolver
    var lastKnownPhysicalKeyboards: [String: PhysicalKeyboard] = [:]
    private var discoveryObserverID: UUID?
    private var inputSourceObserverID: UUID?

    init(
        activityTriggeredSwitching: ActivityTriggeredSwitching,
        setupStore: any SetupDecisionStoring,
        inputMonitoringRecovery: any InputMonitoringRecovering,
        physicalKeyboardDiscovery: PhysicalKeyboardDiscovery,
        inputSources: InputSourceModule,
        physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring,
        designationStore: any ManualPhysicalKeyboardDesignationStoring,
        exclusionStore: any PhysicalKeyboardExclusionStoring,
        integrityKeyProvider: any InstallationIntegrityKeyProviding,
        savedPhysicalKeyboardChanges: SavedPhysicalKeyboardChanges
    ) {
        self.savedPhysicalKeyboardChanges = savedPhysicalKeyboardChanges
        self.activityTriggeredSwitching = activityTriggeredSwitching
        self.setupStore = setupStore
        self.inputMonitoringRecovery = inputMonitoringRecovery
        self.physicalKeyboardDiscovery = physicalKeyboardDiscovery
        self.inputSources = inputSources
        self.physicalKeyboardRecordStore = physicalKeyboardRecordStore
        self.exclusionStore = exclusionStore
        resolver = PhysicalKeyboardPresentationResolver(
            recordStore: physicalKeyboardRecordStore,
            designationStore: designationStore,
            integrityKeyProvider: integrityKeyProvider
        )
        isSetupComplete = setupStore.hasCompletedGuidedSetup
        hasStartedGuidedSetup = setupStore.hasStartedGuidedSetup
        guidedSetupStep = setupStore.hasCompletedGuidedSetup ? .ready : setupStore.guidedSetupStep

        applyExclusionKeysToDiscovery()
        discoveryObserverID = physicalKeyboardDiscovery.observeChanges { [weak self] _ in
            self?.publishPhysicalKeyboards()
        }
        inputSourceObserverID = inputSources.observeChanges { [weak self] in
            guard let self else {
                return
            }

            eligibleInputSources = inputSources.eligibleInputSources
        }

        publishPhysicalKeyboards()
        eligibleInputSources = inputSources.eligibleInputSources
        followSwitchingOutcome()
    }

    /// Composition initializer for focused adapter tests.
    /// Production composition uses the concrete module initializer above.
    convenience init(
        permissionProvider: any ListenPermissionProviding,
        protectedStateProvider: any ProtectedStateProviding = SystemProtectedStateProvider(),
        setupStore: any SetupDecisionStoring,
        inputMonitoringRecovery: any InputMonitoringRecovering,
        physicalKeyboardDiscoverer: any PhysicalKeyboardDiscovering =
            NoOpPhysicalKeyboardDiscoverer(),
        inputSourceProvider: any InputSourceProviding = NoOpInputSourceProvider(),
        inputSourceSelector: any InputSourceSelecting = NoOpInputSourceSelector(),
        physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring =
            InMemoryPhysicalKeyboardRecordStore(),
        physicalKeyboardEventObserver: any PhysicalKeyboardEventObserving =
            NoOpPhysicalKeyboardEventObserver(),
        inputSourceChangeObserver: any InputSourceChangeObserving =
            NoOpInputSourceChangeObserver(),
        designationStore: any ManualPhysicalKeyboardDesignationStoring =
            InMemoryManualPhysicalKeyboardDesignationStore(),
        exclusionStore: any PhysicalKeyboardExclusionStoring =
            InMemoryPhysicalKeyboardExclusionStore(),
        integrityKeyProvider: any InstallationIntegrityKeyProviding =
            InMemoryInstallationIntegrityKeyProvider(),
        appAssignmentStore: any AppAssignmentStoring = InMemoryAppAssignmentStore()
    ) {
        let composition = ProductionFactory.makeActivityTriggeredSwitching(
            permissionProvider: permissionProvider,
            protectedStateProvider: protectedStateProvider,
            setupStore: setupStore,
            physicalKeyboardDiscoverer: physicalKeyboardDiscoverer,
            physicalKeyboardEventObserver: physicalKeyboardEventObserver,
            inputSourceProvider: inputSourceProvider,
            inputSourceSelector: inputSourceSelector,
            inputSourceChangeObserver: inputSourceChangeObserver,
            physicalKeyboardRecordStore: physicalKeyboardRecordStore,
            designationStore: designationStore,
            exclusionStore: exclusionStore,
            integrityKeyProvider: integrityKeyProvider,
            appAssignmentStore: appAssignmentStore
        )
        self.init(
            activityTriggeredSwitching: composition.activityTriggeredSwitching,
            setupStore: composition.setupStore,
            inputMonitoringRecovery: inputMonitoringRecovery,
            physicalKeyboardDiscovery: composition.physicalKeyboardDiscovery,
            inputSources: composition.inputSources,
            physicalKeyboardRecordStore: composition.physicalKeyboardRecordStore,
            designationStore: composition.designationStore,
            exclusionStore: composition.exclusionStore,
            integrityKeyProvider: composition.integrityKeyProvider,
            savedPhysicalKeyboardChanges: composition.savedPhysicalKeyboardChanges
        )
    }

    var activePhysicalKeyboardID: PhysicalKeyboardRecordID? {
        physicalKeyboardDiscovery.activePhysicalKeyboardID
    }

    var activePhysicalKeyboard: PhysicalKeyboard? {
        guard let activePhysicalKeyboardID else {
            return nil
        }

        return physicalKeyboards.first { $0.id == activePhysicalKeyboardID }
    }

    var isActivityTriggeredSwitchingPaused: Bool {
        setupStore.isActivityTriggeredSwitchingPaused
    }

    var physicalKeyboardActionConditions: [PhysicalKeyboardActionCondition] {
        physicalKeyboards.compactMap { physicalKeyboard in
            switch physicalKeyboard.assignmentState {
            case .unassigned:
                .unassigned(physicalKeyboardName: physicalKeyboard.name)
            case .assigned:
                assignedInputSourceName(for: physicalKeyboard) == nil
                    ? .unavailableKeyboardAssignment(physicalKeyboardName: physicalKeyboard.name)
                    : nil
            case .unsupported:
                nil
            }
        }
    }

    func beginGuidedSetup() {
        guard !isSetupComplete else { return }
        if !hasStartedGuidedSetup {
            setupStore.markGuidedSetupStarted()
            hasStartedGuidedSetup = true
            guidedSetupStep = setupStore.guidedSetupStep
        }
        activityTriggeredSwitching.checkAgain()
        advanceIfPermissionGranted()
    }

    func requestPermission() {
        activityTriggeredSwitching.requestPermission()
        advanceIfPermissionGranted()
    }

    func advanceIfPermissionGranted() {
        guard !isSetupComplete, guidedSetupStep == .permission else {
            return
        }
        guard activityTriggeredSwitching.outcome.switchingStatus != .permissionRequired else {
            return
        }

        continueToAssignments()
    }

    func continueToAssignments() {
        guard !isSetupComplete, guidedSetupStep == .permission,
              activityTriggeredSwitching.outcome.switchingStatus != .permissionRequired else { return }
        setupStore.markGuidedSetupStep(.assignments)
        hasStartedGuidedSetup = true
        guidedSetupStep = .assignments
        activityTriggeredSwitching.checkAgain()
    }

    func continueToReady() {
        guard !isSetupComplete, guidedSetupStep == .assignments,
              persistenceError == nil, activityTriggeredSwitching.persistenceError == nil else { return }
        setupStore.markGuidedSetupStep(.ready)
        guidedSetupStep = .ready
    }

    func returnToAssignments() {
        guard !isSetupComplete, guidedSetupStep == .ready else { return }
        setupStore.markGuidedSetupStep(.assignments)
        guidedSetupStep = .assignments
    }

    func completeSetup(destination: GuidedSetupCompletionDestination) {
        guard !isSetupComplete, guidedSetupStep == .ready,
              persistenceError == nil, activityTriggeredSwitching.persistenceError == nil else { return }
        setupStore.markGuidedSetupCompleted()
        isSetupComplete = true
        onGuidedSetupCompleted?(destination)
    }

    func openSystemSettings() {
        inputMonitoringRecovery.openSystemSettings()
    }

    func relaunch() {
        inputMonitoringRecovery.relaunch()
    }

    /// Activity-Triggered Switching watches permission while it is missing.
    /// Guided setup advances as soon as that outcome reports a grant.
    private func followSwitchingOutcome() {
        withObservationTracking {
            _ = activityTriggeredSwitching.outcome.switchingStatus
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.advanceIfPermissionGranted()
                self?.followSwitchingOutcome()
            }
        }
    }
}
