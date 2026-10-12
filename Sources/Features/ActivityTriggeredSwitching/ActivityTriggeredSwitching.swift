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
    private(set) var outcome: ActivityTriggeredSwitchingOutcome
    private(set) var persistenceError: String?
    private(set) var externalChangeResponse: ExternalChangeResponse

    private let permissionProvider: any ListenPermissionProviding
    private let protectedStateProvider: any ProtectedStateProviding
    private let setupStore: any SetupDecisionStoring
    private let physicalKeyboardDiscovery: PhysicalKeyboardDiscovery
    private let inputSources: InputSourceModule
    private let physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring
    private let exclusionStore: any PhysicalKeyboardExclusionStoring
    private let appAssignmentStore: any AppAssignmentStoring
    private let frontmostAppObserver: any FrontmostAppObserving
    private let resolver: PhysicalKeyboardPresentationResolver

    private(set) var isStarted = false
    /// False until Guided setup completes. Activation Activity and App
    /// Activations are then ignored, so no Input Source is selected during setup.
    var appliesKeyboardAssignments = true
    private var eventProtectedDataUnavailable = false
    private var lastKnownListenPermission: ListenPermissionState
    private(set) var switchingWarnings = SwitchingWarnings()
    private(set) var wantedInputSourceGeneration: UInt64 = 0
    private(set) var wantedInputSourceIdentifier: String?
    private(set) var wantedInputSource: WantedInputSource?
    private(set) var verifiedInputSourceIdentifier: String?
    private(set) var observedCurrentInputSourceIdentifier: String?
    private var lastActivePhysicalKeyboard: PhysicalKeyboard?
    private(set) var appAssignments: FrontmostAppAssignments
    private(set) var inputSourceHold = InputSourceHoldTracker()

    private let permissionWatch = ListenPermissionWatch()
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

    func replaceActivePhysicalKeyboard(
        from oldID: PhysicalKeyboardRecordID,
        to newID: PhysicalKeyboardRecordID
    ) {
        guard physicalKeyboardDiscovery.activePhysicalKeyboardID == oldID else {
            return
        }

        if let keyboard = physicalKeyboardDiscovery.physicalKeyboards.first(where: { $0.id == newID }) {
            do {
                lastActivePhysicalKeyboard = try resolver.resolve(keyboard)
            } catch {
                markPersistenceUnavailable()
                return
            }
        }
        physicalKeyboardDiscovery.markActive(newID)
        rebuildOutcome()
    }

    /// Application lifecycle seam. Not part of the product interface.
    func handleLifecycleEvent(_ event: LifecycleEvent) {
        switch event {
        case .willSleep:
            updateUnavailableReason(.sleeping, isActive: true)
        case .didWake:
            updateUnavailableReason(.sleeping, isActive: false)
        case .sessionDidResignActive:
            updateUnavailableReason(.inactiveSession, isActive: true)
        case .sessionDidBecomeActive:
            updateUnavailableReason(.inactiveSession, isActive: false)
        case .protectedDataWillBecomeUnavailable:
            eventProtectedDataUnavailable = true
            updateUnavailableReason(.protectedDataUnavailable, isActive: true)
        case .protectedDataDidBecomeAvailable:
            eventProtectedDataUnavailable = false
            updateUnavailableReason(.protectedDataUnavailable, isActive: false)
        }

        checkAgain()
    }

    /// Internal seam for deterministic module tests.
    func handleActivationActivity(_ activity: PhysicalKeyboardActivationActivity) {
        guard acceptsTrigger(), let rawKeyboard = physicalKeyboardDiscovery.physicalKeyboards.first(where: {
            $0.id == activity.physicalKeyboardID
        }) else {
            return
        }

        inputSources.refreshCurrentIdentifier()
        let physicalKeyboard: PhysicalKeyboard
        do {
            physicalKeyboard = try resolver.resolve(rawKeyboard)
        } catch {
            markPersistenceUnavailable()
            return
        }
        let activeChanged = physicalKeyboardDiscovery.activePhysicalKeyboardID != physicalKeyboard.id
        lastActivePhysicalKeyboard = physicalKeyboard
        physicalKeyboardDiscovery.markActive(physicalKeyboard.id)

        if activeChanged {
            Log.debug(
                .switching,
                "Active Physical Keyboard is now \(physicalKeyboard.name)"
            )
        }

        let wanted = currentWantedInputSource()
        if inputSourceHold.keepsInputSource(
            afterActivationActivityFrom: physicalKeyboard,
            wantedInputSourceIdentifier: wanted?.inputSourceIdentifier,
            currentInputSourceIdentifier: inputSources.currentInputSourceIdentifier
        ) {
            rebuildOutcome()
            return
        }

        if let wanted {
            applyWantedInputSource(wanted)
        }

        rebuildOutcome()
    }

    /// Internal seam for deterministic App Activations. Keyameleon's own
    /// activation is not one, so the Frontmost App stays the previous app.
    func handleAppActivation(_ app: FrontmostApp) {
        guard appAssignments.noteActivation(of: app) else { return }
        // The Frontmost App shows in the outcome even when nothing is selected.
        guard acceptsTrigger() else { return rebuildOutcome() }

        // A change still pending ends with this hold instead of starting a new one.
        inputSources.refreshCurrentIdentifier()
        inputSourceHold.end(reason: "App Activation")
        if let wanted = currentWantedInputSource() {
            applyWantedInputSource(wanted)
        }
        rebuildOutcome()
    }

    /// Whether Activation Activity or an App Activation may select an Input
    /// Source now. Secure Input or unavailable protected data rechecks status instead.
    private func acceptsTrigger() -> Bool {
        guard isStarted, appliesKeyboardAssignments, persistenceError == nil,
              outcome.switchingStatus == .ready else {
            return false
        }

        let protectedState = protectedStateProvider.currentProtectedState()
        if protectedState.isSecureInputEnabled || !protectedState.isProtectedDataAvailable {
            checkAgain()
            return false
        }
        return true
    }

    /// Internal seam for deterministic external Input Source changes.
    func handleExternalInputSourceChange() {
        guard isStarted, persistenceError == nil, outcome.switchingStatus == .ready else {
            return
        }
        let currentIdentifier = inputSources.currentInputSourceIdentifier
        let previousObserved = observedCurrentInputSourceIdentifier
        let previousVerified = verifiedInputSourceIdentifier
        let previousHold = inputSourceHold
        observedCurrentInputSourceIdentifier = currentIdentifier

        if let verified = verifiedInputSourceIdentifier,
           currentIdentifier != verified {
            verifiedInputSourceIdentifier = nil
        }

        // Keyameleon's own selections update the observed Input Source before their
        // notification arrives, so only an External Input Source Change gets here.
        if currentIdentifier != previousObserved {
            inputSourceHold.noteExternalChange(
                to: currentIdentifier,
                response: externalChangeResponse,
                isReady: appliesKeyboardAssignments,
                activePhysicalKeyboardID: lastActivePhysicalKeyboard?.id,
                wantedInputSourceIdentifier: currentWantedInputSource()?.inputSourceIdentifier
            )
        }

        if previousObserved != observedCurrentInputSourceIdentifier
            || previousVerified != verifiedInputSourceIdentifier
            || previousHold != inputSourceHold {
            Log.verbose(
                .switching,
                "Observed Input Source is now \(observedCurrentInputSourceIdentifier ?? "none")"
            )
            rebuildOutcome()
        }
    }

    private func updateObservation(for status: SwitchingStatus) {
        updatePermissionWatch(for: status)
        guard isStarted else {
            return
        }

        if status.allowsPhysicalKeyboardDiscovery {
            physicalKeyboardDiscovery.start()
        } else {
            physicalKeyboardDiscovery.stop()
        }

        if status == .ready, persistenceError == nil {
            physicalKeyboardDiscovery.startActivationActivityObservation { [weak self] activity in
                self?.handleActivationActivity(activity)
            }
            inputSources.startObservingChanges()
        } else {
            physicalKeyboardDiscovery.stopActivationActivityObservation()
            inputSources.stopObservingChanges()
        }
    }

    private func handleDiscoveryChange() {
        guard persistenceError == nil else {
            return
        }
        if let activeID = physicalKeyboardDiscovery.activePhysicalKeyboardID,
           let keyboard = physicalKeyboardDiscovery.physicalKeyboards.first(where: {
               $0.id == activeID
           }) {
            do {
                lastActivePhysicalKeyboard = try resolver.resolve(keyboard)
            } catch {
                markPersistenceUnavailable()
                return
            }
        }
        do {
            try reevaluateUnavailableAssignments()
        } catch {
            markPersistenceUnavailable()
            return
        }
        rebuildOutcome()
    }

    private func handleDiscoveryRecordChange(
        _ change: PhysicalKeyboardDiscoveryRecordChange
    ) {
        switch change {
        case let .connected(physicalKeyboardID, name):
            let displayName = physicalKeyboardName(physicalKeyboardID, fallback: name)
            Log.debug(.switching, "Physical Keyboard connected (\(displayName))")
        case let .disconnected(physicalKeyboardID, name):
            let displayName = physicalKeyboardName(physicalKeyboardID, fallback: name)
            Log.debug(.switching, "Physical Keyboard disconnected (\(displayName))")
            if inputSourceHold.endOnDisconnect(of: physicalKeyboardID, name: displayName) {
                rebuildOutcome()
            }
        }
    }

    /// The name the panel shows, so a log line names the same Physical Keyboard
    /// the user sees. Catalog entries carry no custom name, and a disconnected
    /// Physical Keyboard is gone from the catalog, so the saved record comes
    /// first and the discovery payload is the last resort.
    private func physicalKeyboardName(
        _ physicalKeyboardID: PhysicalKeyboardRecordID?,
        fallback: String? = nil
    ) -> String {
        guard let physicalKeyboardID else {
            return fallback ?? "name unknown"
        }
        do {
            if let savedName = try physicalKeyboardRecordStore
                .record(forIdentityKey: physicalKeyboardID.rawValue)?
                .name {
                return savedName
            }
        } catch {
            markPersistenceUnavailable()
        }
        if let catalogName = physicalKeyboardDiscovery.physicalKeyboards
            .first(where: { $0.id == physicalKeyboardID })?
            .name {
            return catalogName
        }
        return fallback ?? "name unknown"
    }

    private func handleInputSourceModuleChange() {
        guard persistenceError == nil else {
            return
        }
        handleExternalInputSourceChange()
        guard persistenceError == nil else {
            return
        }
        do {
            try reevaluateUnavailableAssignments()
        } catch {
            markPersistenceUnavailable()
            return
        }
        rebuildOutcome()
    }

    private func handleRecordChange() {
        guard persistenceError == nil else {
            return
        }
        do {
            let records = try physicalKeyboardRecordStore.allRecords()
            reconcileWantedAssignmentFromRecords(records)
            try reevaluateUnavailableAssignments(records: records)
        } catch {
            markPersistenceUnavailable()
            return
        }
        rebuildOutcome()
    }

    private func reconcileWantedAssignmentFromRecords(_ records: [SavedPhysicalKeyboardRecord]) {
        guard let physicalKeyboardID = wantedInputSource?.physicalKeyboardID else {
            return
        }

        reconcileWantedInputSource(with: records
            .first { $0.identityKey == physicalKeyboardID.rawValue }?
            .keyboardAssignment?.inputSourceIdentifier)
    }

    /// Follows an edit (a new Input Source) or removal (nil) of the assignment
    /// the Wanted Input Source came from.
    private func reconcileWantedInputSource(with inputSourceIdentifier: String?) {
        guard let wanted = wantedInputSource else {
            return
        }

        guard let inputSourceIdentifier else {
            wantedInputSource = nil
            wantedInputSourceIdentifier = nil
            verifiedInputSourceIdentifier = nil
            switchingWarnings.clear(.selectionFailure)
            return
        }

        guard inputSourceIdentifier != wanted.inputSourceIdentifier else {
            return
        }

        wantedInputSource = WantedInputSource(origin: wanted.origin, inputSourceIdentifier: inputSourceIdentifier)
        wantedInputSourceIdentifier = inputSourceIdentifier
        if verifiedInputSourceIdentifier != inputSourceIdentifier {
            verifiedInputSourceIdentifier = nil
        }
        switchingWarnings.clear(.selectionFailure)
    }

    /// The Wanted Input Source for the Frontmost App and the Active Physical Keyboard.
    private func currentWantedInputSource() -> WantedInputSource? {
        WantedInputSource.resolve(
            appAssignment: appAssignments.frontmostAssignment,
            activePhysicalKeyboard: lastActivePhysicalKeyboard
        )
    }

    /// Selects the Wanted Input Source unless it is unavailable or already verified and current.
    private func applyWantedInputSource(_ wanted: WantedInputSource) {
        let wantedIdentifier = wanted.inputSourceIdentifier
        let currentIdentifier = inputSources.currentInputSourceIdentifier
        observedCurrentInputSourceIdentifier = currentIdentifier
        wantedInputSource = wanted

        if isUnavailable(wantedIdentifier) {
            switchingWarnings.clear(.selectionFailure)
            switchingWarnings.open(.unavailableAssignment(for: wanted))
            if verifiedInputSourceIdentifier == wantedIdentifier {
                verifiedInputSourceIdentifier = nil
            }
            wantedInputSourceIdentifier = wantedIdentifier
        } else if wantedInputSourceIdentifier == wantedIdentifier,
                  verifiedInputSourceIdentifier == wantedIdentifier,
                  currentIdentifier == wantedIdentifier {
            switchingWarnings.clear(.selectionFailure)
        } else {
            wantedInputSourceGeneration &+= 1
            let generation = wantedInputSourceGeneration
            wantedInputSourceIdentifier = wantedIdentifier
            _ = selectWantedInputSource(generation: generation)
        }
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

    private func selectWantedInputSource(generation: UInt64) -> Bool {
        guard persistenceError == nil, let wanted = wantedInputSource else {
            return false
        }
        let inputSourceIdentifier = wanted.inputSourceIdentifier
        let keyboardName = switch wanted.origin {
        case let .keyboard(physicalKeyboardID): physicalKeyboardName(physicalKeyboardID)
        case let .app(_, name): name
        }
        guard persistenceError == nil else { return false }
        let verified = inputSources.selectAndVerifyInputSource(identifier: inputSourceIdentifier)
        guard generation == wantedInputSourceGeneration else {
            return false
        }

        if verified {
            verifiedInputSourceIdentifier = inputSourceIdentifier
            observedCurrentInputSourceIdentifier = inputSourceIdentifier
            switchingWarnings.clear(.selectionFailure)
            Log.debug(
                .switching,
                "Selected Input Source \(inputSourceIdentifier) for "
                    + "\(keyboardName)"
            )
            return true
        }

        if verifiedInputSourceIdentifier == inputSourceIdentifier {
            verifiedInputSourceIdentifier = nil
        }
        observedCurrentInputSourceIdentifier = inputSources.currentInputSourceIdentifier
        switchingWarnings.open(.selectionFailure(inputSourceIdentifier: inputSourceIdentifier))
        Log.warning(
            .switching,
            "Could not select Input Source \(inputSourceIdentifier) for "
                + "\(keyboardName)"
        )
        return false
    }
    private func markPersistenceUnavailable() {
        guard persistenceError == nil else { return }
        Log.error(.switching, "Saved Physical Keyboard data could not be read")
        persistenceError = String(localized: .persistenceReadFailed)
        physicalKeyboardDiscovery.stopActivationActivityObservation()
        inputSources.stopObservingChanges()
    }

    private func isUnavailable(_ assignment: KeyboardAssignment) -> Bool {
        isUnavailable(assignment.inputSourceIdentifier)
    }

    private func isUnavailable(_ inputSourceIdentifier: String) -> Bool {
        !eligibleIdentifiers.contains(inputSourceIdentifier)
    }

    private var eligibleIdentifiers: Set<String> {
        Set(inputSources.eligibleInputSources.map(\.identifier))
    }

    private func updateUnavailableReason(
        _ reason: SwitchingUnavailableReason,
        isActive: Bool
    ) {
        let reasons = SwitchingUnavailableReason.updating(
            outcome.temporarilyUnavailableReasons, reason, isActive: isActive
        )
        guard reasons != outcome.temporarilyUnavailableReasons else {
            return
        }

        outcome = replacingOutcome(reasons: reasons)
    }

    private func reconcileProtectedState() {
        outcome = replacingOutcome(reasons: SwitchingUnavailableReason.reconciling(
            outcome.temporarilyUnavailableReasons,
            protectedState: protectedStateProvider.currentProtectedState(),
            eventProtectedDataUnavailable: eventProtectedDataUnavailable
        ))
    }

    /// Opens or clears a warning for every saved Keyboard and App Assignment
    /// whose Input Source is unavailable. Returns whether a keyboard warning changed.
    @discardableResult
    private func reevaluateUnavailableAssignments(records: [SavedPhysicalKeyboardRecord]? = nil) throws -> Bool {
        switchingWarnings.reevaluate(appAssignments, eligibleIdentifiers: eligibleIdentifiers)
        return switchingWarnings.reevaluateKeyboardAssignments(
            try records ?? physicalKeyboardRecordStore.allRecords(),
            eligibleIdentifiers: eligibleIdentifiers,
            excludedKeys: Set(exclusionStore.allExclusions().map(\.key))
        )
    }

    private func rebuildOutcome() {
        guard persistenceError == nil else { return }
        let previousLastActivePhysicalKeyboard = lastActivePhysicalKeyboard
        do {
            try rebuildOutcomeFromRecords()
        } catch {
            lastActivePhysicalKeyboard = previousLastActivePhysicalKeyboard
            markPersistenceUnavailable()
        }
    }
    private func rebuildOutcomeFromRecords() throws {
        let activeKeyboard = try activeKeyboardForOutcome()
        let currentIdentifier = observedCurrentInputSourceIdentifier
            ?? inputSources.currentInputSourceIdentifier
        let currentName = currentIdentifier.flatMap(displayName(forInputSourceIdentifier:))

        let assignment = activeKeyboard.map(assignmentCondition)
            ?? .none
        let wanted = currentWantedInputSource()
        let mismatch: ActivityTriggeredSwitchingMismatch? = {
            guard let wanted,
                  let currentIdentifier, currentIdentifier != wanted.inputSourceIdentifier,
                  let currentName = displayName(forInputSourceIdentifier: currentIdentifier),
                  let assignedName = displayName(forInputSourceIdentifier: wanted.inputSourceIdentifier)
            else { return nil }
            return ActivityTriggeredSwitchingMismatch(
                currentName: currentName,
                assignedName: assignedName,
                appName: appAssignments.frontmostAssignment == nil ? nil : appAssignments.frontmostApp?.name
            )
        }()

        let warnings = try switchingWarnings.sorted.map { warning in
            ActivityTriggeredSwitchingWarning(
                physicalKeyboardName: try warningName(for: warning),
                category: warning.category,
                recoveryAction: warning.recoveryAction
            )
        }

        let availableActions = availableActions(warnings: warnings)
        let newOutcome = ActivityTriggeredSwitchingOutcome(
            switchingStatus: outcome.switchingStatus,
            temporarilyUnavailableReasons: outcome.temporarilyUnavailableReasons,
            activePhysicalKeyboard: activeKeyboard.map {
                ActivityTriggeredSwitchingActivePhysicalKeyboard(
                    name: $0.name,
                    connectionState: $0.connectionState,
                    assignment: assignmentCondition($0)
                )
            },
            currentKeyboardAssignment: assignment,
            currentInputSourceName: currentName,
            mismatch: mismatch,
            warnings: warnings,
            availableActions: availableActions,
            inputSourceHold: inputSourceHold.hold?.response,
            frontmostAppAssignment: appAssignments.outcome(eligibleInputSources: inputSources.eligibleInputSources)
        )
        guard newOutcome != outcome else {
            return
        }

        outcome = newOutcome
    }

    private func activeKeyboardForOutcome() throws -> PhysicalKeyboard? {
        if let activePhysicalKeyboardID = physicalKeyboardDiscovery.activePhysicalKeyboardID,
           let connected = physicalKeyboardDiscovery.physicalKeyboards.first(where: {
               $0.id == activePhysicalKeyboardID
           }) {
            let resolved = try resolver.resolve(connected)
            lastActivePhysicalKeyboard = resolved
            return resolved
        }

        return lastActivePhysicalKeyboard?.asDisconnected()
    }

    private func assignmentCondition(
        _ physicalKeyboard: PhysicalKeyboard
    ) -> ActivityTriggeredSwitchingKeyboardAssignment {
        switch physicalKeyboard.assignmentState {
        case .unassigned:
            .unassigned
        case let .assigned(assignment):
            if isUnavailable(assignment) {
                .unavailable
            } else if let name = displayName(
                forInputSourceIdentifier: assignment.inputSourceIdentifier
            ) {
                .assigned(name: name)
            } else {
                .unavailable
            }
        case let .unsupported(reason):
            .unsupported(reason)
        }
    }

    private func warningName(for warning: SwitchingWarning) throws -> String? {
        if case let .unavailableAppAssignment(bundleIdentifier) = warning.cause {
            return appAssignments.assignments[bundleIdentifier]?.appName
        }
        if warning.cause == .selectionFailure, case let .app(_, name) = wantedInputSource?.origin {
            return name
        }
        guard case let .unavailableKeyboardAssignment(physicalKeyboardID) = warning.cause else {
            return try activeKeyboardForOutcome()?.name
        }

        if let keyboard = physicalKeyboardDiscovery.physicalKeyboards.first(where: {
            $0.id == physicalKeyboardID
        }) {
            return try resolver.resolve(keyboard).name
        }

        return try physicalKeyboardRecordStore.record(
            forIdentityKey: physicalKeyboardID.rawValue
        )?.name
    }

    private func displayName(forInputSourceIdentifier identifier: String) -> String? {
        inputSources.eligibleInputSources.first { $0.identifier == identifier }?.name
    }
}

// MARK: - Input Source Hold

extension ActivityTriggeredSwitching {
    /// Saves the External Change Response. Changing it ends any Input Source Hold.
    func setExternalChangeResponse(_ response: ExternalChangeResponse) {
        guard response != externalChangeResponse else {
            return
        }

        setupStore.setExternalChangeResponse(response)
        externalChangeResponse = response
        Log.debug(.switching, "External Change Response is now \(response.rawValue)")
        inputSourceHold.end(reason: "External Change Response changed")
        rebuildOutcome()
    }

    /// Ends the Input Source Hold and applies the Wanted Input Source.
    func switchBackNow() {
        guard inputSourceHold.hold != nil else {
            return
        }

        // A change still pending joins this hold instead of starting a new one.
        inputSources.refreshCurrentIdentifier()
        inputSourceHold.end(reason: "Switch Back Now")
        if persistenceError == nil, outcome.switchingStatus == .ready,
           let wanted = currentWantedInputSource() {
            applyWantedInputSource(wanted)
        }
        rebuildOutcome()
    }

    /// Setup seam: the person edited or removed one Physical Keyboard's Keyboard Assignment.
    func keyboardAssignmentDidChange(_ physicalKeyboardID: PhysicalKeyboardRecordID) {
        let activeID = physicalKeyboardDiscovery.activePhysicalKeyboardID
        if inputSourceHold.endOnKeyboardAssignmentChange(of: physicalKeyboardID, activePhysicalKeyboardID: activeID) {
            rebuildOutcome()
        }
    }
}

// MARK: - App Assignments

extension ActivityTriggeredSwitching {
    /// Rereads App Assignments after a saved change. Editing or removing the
    /// Frontmost App's App Assignment ends any Input Source Hold, and a Wanted
    /// Input Source from it follows the edit without selecting anything.
    private func handleAppAssignmentChange() {
        guard persistenceError == nil else {
            return
        }
        let frontmostAssignmentChanged: Bool
        do {
            let saved = try appAssignmentStore.allAppAssignments()
            frontmostAssignmentChanged = appAssignments.replaceAssignments(with: saved)
        } catch {
            markPersistenceUnavailable()
            return
        }

        if frontmostAssignmentChanged {
            inputSourceHold.end(reason: "App Assignment changed")
        }
        if let bundleIdentifier = wantedInputSource?.appBundleIdentifier {
            reconcileWantedInputSource(with: appAssignments.assignments[bundleIdentifier]?.inputSourceIdentifier)
        }
        switchingWarnings.reevaluate(appAssignments, eligibleIdentifiers: eligibleIdentifiers)
        rebuildOutcome()
    }
}

// MARK: - Input Monitoring

extension ActivityTriggeredSwitching {
    /// Actions depend on the Input Monitoring decision, not only on status:
    /// an unknown decision is requested, a denied one is fixed in Settings.
    private func availableActions(
        warnings: [ActivityTriggeredSwitchingWarning]
    ) -> Set<ActivityTriggeredSwitchingAction> {
        ActivityTriggeredSwitchingAction.available(
            for: outcome.switchingStatus,
            listenPermission: lastKnownListenPermission,
            warnings: warnings,
            isPaused: setupStore.isActivityTriggeredSwitchingPaused
        )
    }

    private func replacingOutcome(
        status: SwitchingStatus? = nil,
        reasons: [SwitchingUnavailableReason]? = nil
    ) -> ActivityTriggeredSwitchingOutcome {
        outcome.replacing(
            status: status,
            reasons: reasons,
            listenPermission: lastKnownListenPermission,
            isPaused: setupStore.isActivityTriggeredSwitchingPaused
        )
    }

    /// Polls permission only while it is missing, and refreshes the outcome
    /// when the decision changes (alert answered, or grant applied).
    private func updatePermissionWatch(for status: SwitchingStatus) {
        guard isStarted, status == .permissionRequired else {
            return permissionWatch.stop()
        }
        permissionWatch.start { [weak self] in
            guard let self, permissionProvider.checkListenPermission() != lastKnownListenPermission else { return }
            checkAgain()
        }
    }
}
