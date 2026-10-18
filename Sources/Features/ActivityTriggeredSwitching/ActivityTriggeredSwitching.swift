import Foundation
import Observation

/// Deep Activity-Triggered Switching module.
///
/// It selects the Wanted Input Source after Activation Activity or an App
/// Activation. External callers learn one outcome and nine product operations. Observation,
/// exact selection, recovery, lifecycle, and adapter details stay inside this
/// module.
@MainActor
@Observable
final class ActivityTriggeredSwitching {
    var outcome: ActivityTriggeredSwitchingOutcome
    private(set) var persistenceError: String?
    var externalChangeResponse: ExternalChangeResponse

    let permissionProvider: any ListenPermissionProviding
    let protectedStateProvider: any ProtectedStateProviding
    let setupStore: any SetupDecisionStoring
    let physicalKeyboardDiscovery: PhysicalKeyboardDiscovery
    let inputSources: InputSourceModule
    let physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring
    let exclusionStore: any PhysicalKeyboardExclusionStoring
    let appAssignmentStore: any AppAssignmentStoring
    private let frontmostAppObserver: any FrontmostAppObserving
    let resolver: PhysicalKeyboardPresentationResolver

    private(set) var isStarted = false
    /// False until Guided setup completes. Activation Activity and App
    /// Activations are then ignored, so no Input Source is selected during setup.
    var appliesKeyboardAssignments = true
    var eventProtectedDataUnavailable = false
    var lastKnownListenPermission: ListenPermissionState
    var switchingWarnings = SwitchingWarnings()
    var wantedInputSourceGeneration: UInt64 = 0
    var wantedInputSourceIdentifier: String?
    var wantedInputSource: WantedInputSource?
    var verifiedInputSourceIdentifier: String?
    var observedCurrentInputSourceIdentifier: String?
    var lastActivePhysicalKeyboard: PhysicalKeyboard?
    var appAssignments: FrontmostAppAssignments
    var inputSourceHold = InputSourceHoldTracker()

    let permissionWatch = ListenPermissionWatch()
    private var discoveryObserverID: UUID?
    private var discoveryRecordObserverID: UUID?
    private var inputSourceObserverID: UUID?

    var testingPhysicalKeyboardDiscovery: PhysicalKeyboardDiscovery {
        physicalKeyboardDiscovery
    }

    func markActiveForTesting(_ physicalKeyboardID: PhysicalKeyboardRecordID) {
        guard let keyboard = physicalKeyboardDiscovery.physicalKeyboards.first(where: {
            $0.id == physicalKeyboardID
        }) else {
            return
        }

        do {
            lastActivePhysicalKeyboard = try resolver.resolve(keyboard)
        } catch {
            markPersistenceUnavailable()
            return
        }
        physicalKeyboardDiscovery.markActive(physicalKeyboardID)
        rebuildOutcome()
    }
    func retryPersistenceRead() {
        do {
            try resolver.verifyPersistenceRead()
            persistenceError = nil
            handleAppAssignmentChange()
            handleRecordChange()
            checkAgain()
        } catch {
            markPersistenceUnavailable()
        }
    }

    init(
        permissionProvider: any ListenPermissionProviding,
        protectedStateProvider: any ProtectedStateProviding = SystemProtectedStateProvider(),
        setupStore: any SetupDecisionStoring,
        physicalKeyboardDiscovery: PhysicalKeyboardDiscovery,
        inputSources: InputSourceModule,
        physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring,
        designationStore: any ManualPhysicalKeyboardDesignationStoring,
        exclusionStore: any PhysicalKeyboardExclusionStoring,
        integrityKeyProvider: any InstallationIntegrityKeyProviding,
        appAssignmentStore: any AppAssignmentStoring,
        frontmostAppObserver: any FrontmostAppObserving,
        ownBundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) {
        self.permissionProvider = permissionProvider
        self.protectedStateProvider = protectedStateProvider
        self.setupStore = setupStore
        self.physicalKeyboardDiscovery = physicalKeyboardDiscovery
        self.inputSources = inputSources
        self.physicalKeyboardRecordStore = physicalKeyboardRecordStore
        self.exclusionStore = exclusionStore
        self.appAssignmentStore = appAssignmentStore
        self.frontmostAppObserver = frontmostAppObserver
        appAssignments = FrontmostAppAssignments(ownBundleIdentifier: ownBundleIdentifier)
        resolver = PhysicalKeyboardPresentationResolver(
            recordStore: physicalKeyboardRecordStore,
            designationStore: designationStore,
            integrityKeyProvider: integrityKeyProvider
        )
        observedCurrentInputSourceIdentifier = inputSources.currentInputSourceIdentifier
        externalChangeResponse = setupStore.externalChangeResponse

        let protectedState = protectedStateProvider.currentProtectedState()
        let reasons = SwitchingUnavailableReason.initial(
            protectedState: protectedState,
            eventProtectedDataUnavailable: false
        )
        let permission = permissionProvider.checkListenPermission()
        lastKnownListenPermission = permission
        outcome = ActivityTriggeredSwitchingOutcome(
            switchingStatus: SwitchingStatus.resolve(
                listenPermission: permission,
                isTemporarilyUnavailable: !reasons.isEmpty,
                isPaused: setupStore.isActivityTriggeredSwitchingPaused
            ),
            temporarilyUnavailableReasons: reasons,
            activePhysicalKeyboard: nil,
            currentKeyboardAssignment: .none,
            currentInputSourceName: nil,
            mismatch: nil,
            warnings: [],
            availableActions: []
        )

        rebuildOutcome()
    }

    deinit {
        // Observation adapters are stopped by `stop()` while still MainActor-isolated.
    }

    func start() {
        guard !isStarted else {
            return
        }

        isStarted = true
        discoveryObserverID = physicalKeyboardDiscovery.observeChanges { [weak self] _ in
            self?.handleDiscoveryChange()
        }
        discoveryRecordObserverID = physicalKeyboardDiscovery.observeRecordChanges { [weak self] change in
            self?.handleDiscoveryRecordChange(change)
        }
        inputSourceObserverID = inputSources.observeChanges { [weak self] in
            self?.handleInputSourceModuleChange()
        }
        physicalKeyboardRecordStore.startObservingChanges { [weak self] in
            self?.handleRecordChange()
        }
        appAssignmentStore.startObservingChanges { [weak self] in
            self?.handleAppAssignmentChange()
        }
        if let activeApp = frontmostAppObserver.activeApp {
            _ = appAssignments.noteActivation(of: activeApp)
        }
        frontmostAppObserver.start { [weak self] app in
            self?.handleAppActivation(app)
        }
        handleAppAssignmentChange()
        checkAgain()
    }

    func stop() {
        guard isStarted else {
            return
        }

        physicalKeyboardRecordStore.stopObservingChanges()
        appAssignmentStore.stopObservingChanges()
        frontmostAppObserver.stop()
        physicalKeyboardDiscovery.stop()
        inputSources.stopObservingChanges()
        if let discoveryObserverID {
            physicalKeyboardDiscovery.removeObserver(discoveryObserverID)
        }
        if let discoveryRecordObserverID {
            physicalKeyboardDiscovery.removeRecordChangeObserver(discoveryRecordObserverID)
        }
        if let inputSourceObserverID {
            inputSources.removeObserver(inputSourceObserverID)
        }
        self.discoveryObserverID = nil
        self.discoveryRecordObserverID = nil
        self.inputSourceObserverID = nil
        isStarted = false
        updatePermissionWatch(for: outcome.switchingStatus)
        rebuildOutcome()
    }

    func requestPermission() {
        guard outcome.hasAction(.requestPermission) else {
            return
        }

        _ = permissionProvider.requestListenPermission()
        checkAgain()
    }

    func checkAgain() {
        let previousStatus = outcome.switchingStatus
        reconcileProtectedState()
        let permission = permissionProvider.checkListenPermission()
        lastKnownListenPermission = permission
        inputSources.refresh()
        observedCurrentInputSourceIdentifier = inputSources.currentInputSourceIdentifier
        if persistenceError == nil {
            do {
                try reevaluateUnavailableAssignments()
            } catch {
                markPersistenceUnavailable()
            }
        }

        let status = SwitchingStatus.resolve(
            listenPermission: permission,
            isTemporarilyUnavailable: !outcome.temporarilyUnavailableReasons.isEmpty,
            isPaused: setupStore.isActivityTriggeredSwitchingPaused
        )
        recordStatusChange(from: previousStatus, to: status)
        outcome = replacingOutcome(status: status)
        updateObservation(for: status)
        rebuildOutcome()
    }

    func pause() {
        guard outcome.hasAction(.pause) else {
            return
        }

        inputSourceHold.end(reason: "paused")
        setupStore.setActivityTriggeredSwitchingPaused(true)
        checkAgain()
    }

    func resume() {
        guard outcome.hasAction(.resume) else {
            return
        }

        inputSourceHold.end(reason: "resumed")
        setupStore.setActivityTriggeredSwitchingPaused(false)
        checkAgain()
    }

    func retryNow() {
        guard persistenceError == nil,
              outcome.hasAction(.retryNow),
              let wanted = wantedInputSource
        else {
            return
        }

        inputSources.refresh()
        if isUnavailable(wanted.inputSourceIdentifier) {
            switchingWarnings.clear(.selectionFailure)
            switchingWarnings.open(.unavailableAssignment(for: wanted))
            rebuildOutcome()
            return
        }

        wantedInputSourceGeneration &+= 1
        let generation = wantedInputSourceGeneration
        wantedInputSourceIdentifier = wanted.inputSourceIdentifier
        _ = selectWantedInputSource(generation: generation)
        rebuildOutcome()
    }

    /// Internal management seam used when a saved Physical Keyboard is
    /// forgotten, excluded, or explicitly replaced.
    ///
    /// A Wanted Input Source from its Keyboard Assignment goes with it: Retry Now
    /// must not select an Input Source for a Physical Keyboard the person just removed.
    func forgetPhysicalKeyboard(_ physicalKeyboardID: PhysicalKeyboardRecordID) {
        keyboardAssignmentDidChange(physicalKeyboardID)
        var changed = false

        if wantedInputSource?.physicalKeyboardID == physicalKeyboardID {
            wantedInputSource = nil
            wantedInputSourceIdentifier = nil
            switchingWarnings.clear(.selectionFailure)
            changed = true
        }

        if physicalKeyboardDiscovery.activePhysicalKeyboardID == physicalKeyboardID {
            lastActivePhysicalKeyboard = nil
            physicalKeyboardDiscovery.clearActive(if: physicalKeyboardID)
            changed = true
        }

        guard changed else {
            return
        }

        rebuildOutcome()
    }

    private func recordStatusChange(from previous: SwitchingStatus, to current: SwitchingStatus) {
        guard previous != current else {
            return
        }

        Log.debug(.switching, "Switching Status is now \(current.rawValue)")
        if current == .permissionRequired {
            Log.warning(.switching, "Listen permission is required")
        }
    }

    func markPersistenceUnavailable() {
        guard persistenceError == nil else { return }
        Log.error(.switching, "Saved Physical Keyboard data could not be read")
        persistenceError = String(localized: .persistenceReadFailed)
        physicalKeyboardDiscovery.stopActivationActivityObservation()
        inputSources.stopObservingChanges()
    }

    private func reconcileProtectedState() {
        outcome = replacingOutcome(reasons: SwitchingUnavailableReason.reconciling(
            outcome.temporarilyUnavailableReasons,
            protectedState: protectedStateProvider.currentProtectedState(),
            eventProtectedDataUnavailable: eventProtectedDataUnavailable
        ))
    }
}
