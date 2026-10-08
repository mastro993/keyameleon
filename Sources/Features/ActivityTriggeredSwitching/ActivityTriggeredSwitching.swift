import Foundation
import Observation

/// Deep Activity-Triggered Switching module.
///
/// External callers learn one outcome and seven product operations. Observation,
/// exact selection, recovery, lifecycle, and adapter details stay inside this
/// module.
@MainActor
@Observable
final class ActivityTriggeredSwitching {
    private(set) var outcome: ActivityTriggeredSwitchingOutcome
    private(set) var persistenceError: String?

    private let permissionProvider: any ListenPermissionProviding
    private let protectedStateProvider: any ProtectedStateProviding
    private let setupStore: any SetupDecisionStoring
    private let physicalKeyboardDiscovery: PhysicalKeyboardDiscovery
    private let inputSources: InputSourceModule
    private let physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring
    private let exclusionStore: any PhysicalKeyboardExclusionStoring
    private let resolver: PhysicalKeyboardPresentationResolver

    private var isStarted = false
    /// False until Guided setup completes. Activation Activity is then
    /// ignored, so no Input Source is selected during setup.
    var appliesKeyboardAssignments = true
    private var eventProtectedDataUnavailable = false
    private var lastKnownListenPermission: ListenPermissionState
    private var activeWarningByCause: [SwitchingWarning.Cause: SwitchingWarning] = [:]
    private var warningEpisodeCount = 0
    private var wantedKeyboardAssignmentGeneration: UInt64 = 0
    private var wantedKeyboardAssignmentIdentifier: String?
    private var wantedKeyboardAssignment: WantedKeyboardAssignment?
    private var verifiedKeyboardAssignmentIdentifier: String?
    private var observedCurrentInputSourceIdentifier: String?
    private var lastActivePhysicalKeyboard: PhysicalKeyboard?

    private let permissionWatch = ListenPermissionWatch()
    private var discoveryObserverID: UUID?
    private var discoveryRecordObserverID: UUID?
    private var inputSourceObserverID: UUID?

    // Internal adapter evidence used by focused module tests. It is not part
    // of the product outcome.
    var testingActiveWarnings: [SwitchingWarning] {
        activeWarnings
    }

    var testingWarningEpisodeCount: Int {
        warningEpisodeCount
    }

    var testingVerifiedKeyboardAssignmentIdentifier: String? {
        verifiedKeyboardAssignmentIdentifier
    }

    var testingWantedKeyboardAssignmentIdentifier: String? {
        wantedKeyboardAssignmentIdentifier
    }

    var testingWantedKeyboardAssignmentGeneration: UInt64 {
        wantedKeyboardAssignmentGeneration
    }

    var testingObservedCurrentInputSourceIdentifier: String? {
        observedCurrentInputSourceIdentifier
    }

    var testingPhysicalKeyboardDiscovery: PhysicalKeyboardDiscovery {
        physicalKeyboardDiscovery
    }

    var testingWantedKeyboardAssignment: WantedKeyboardAssignment? {
        wantedKeyboardAssignment
    }

    var testingIsStarted: Bool {
        isStarted
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
        integrityKeyProvider: any InstallationIntegrityKeyProviding
    ) {
        self.permissionProvider = permissionProvider
        self.protectedStateProvider = protectedStateProvider
        self.setupStore = setupStore
        self.physicalKeyboardDiscovery = physicalKeyboardDiscovery
        self.inputSources = inputSources
        self.physicalKeyboardRecordStore = physicalKeyboardRecordStore
        self.exclusionStore = exclusionStore
        resolver = PhysicalKeyboardPresentationResolver(
            recordStore: physicalKeyboardRecordStore,
            designationStore: designationStore,
            integrityKeyProvider: integrityKeyProvider
        )
        observedCurrentInputSourceIdentifier = inputSources.currentInputSourceIdentifier

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
        checkAgain()
    }

    func stop() {
        guard isStarted else {
            return
        }

        physicalKeyboardRecordStore.stopObservingChanges()
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
                _ = try reevaluateUnavailableKeyboardAssignments()
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

        setupStore.setActivityTriggeredSwitchingPaused(true)
        checkAgain()
    }

    func resume() {
        guard outcome.hasAction(.resume) else {
            return
        }

        setupStore.setActivityTriggeredSwitchingPaused(false)
        checkAgain()
    }

    func retryNow() {
        guard persistenceError == nil,
              outcome.hasAction(.retryNow),
              let wanted = wantedKeyboardAssignment,
              let assignment = KeyboardAssignment(
                  inputSourceIdentifier: wanted.inputSourceIdentifier
              )
        else {
            return
        }

        inputSources.refresh()
        if isUnavailable(assignment) {
            clearWarning(cause: .selectionFailure)
            openWarning(
                .unavailableKeyboardAssignment(
                    physicalKeyboardID: wanted.physicalKeyboardID,
                    inputSourceIdentifier: wanted.inputSourceIdentifier
                )
            )
            rebuildOutcome()
            return
        }

        wantedKeyboardAssignmentGeneration &+= 1
        let generation = wantedKeyboardAssignmentGeneration
        wantedKeyboardAssignmentIdentifier = wanted.inputSourceIdentifier
        _ = applyWantedKeyboardAssignment(
            wanted.inputSourceIdentifier,
            generation: generation
        )
        rebuildOutcome()
    }

    /// Internal management seam used when a saved Physical Keyboard is
    /// forgotten, excluded, or explicitly replaced.
    ///
    /// The wanted Keyboard Assignment goes with it: Retry Now must not select an
    /// Input Source for a Physical Keyboard the person just removed.
    func forgetPhysicalKeyboard(_ physicalKeyboardID: PhysicalKeyboardRecordID) {
        var changed = false

        if wantedKeyboardAssignment?.physicalKeyboardID == physicalKeyboardID {
            wantedKeyboardAssignment = nil
            wantedKeyboardAssignmentIdentifier = nil
            clearWarning(cause: .selectionFailure)
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
        guard isStarted, appliesKeyboardAssignments, persistenceError == nil,
              outcome.switchingStatus == .ready else {
            return
        }

        let protectedState = protectedStateProvider.currentProtectedState()
        if protectedState.isSecureInputEnabled || !protectedState.isProtectedDataAvailable {
            checkAgain()
            return
        }

        guard let rawKeyboard = physicalKeyboardDiscovery.physicalKeyboards.first(where: {
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

        switch physicalKeyboard.assignmentState {
        case let .assigned(assignment):
            let wantedIdentifier = assignment.inputSourceIdentifier
            let currentIdentifier = inputSources.currentInputSourceIdentifier
            observedCurrentInputSourceIdentifier = currentIdentifier
            wantedKeyboardAssignment = WantedKeyboardAssignment(
                physicalKeyboardID: physicalKeyboard.id,
                inputSourceIdentifier: wantedIdentifier
            )

            if isUnavailable(assignment) {
                clearWarning(cause: .selectionFailure)
                openWarning(
                    .unavailableKeyboardAssignment(
                        physicalKeyboardID: physicalKeyboard.id,
                        inputSourceIdentifier: wantedIdentifier
                    )
                )
                if verifiedKeyboardAssignmentIdentifier == wantedIdentifier {
                    verifiedKeyboardAssignmentIdentifier = nil
                }
                wantedKeyboardAssignmentIdentifier = wantedIdentifier
            } else if wantedKeyboardAssignmentIdentifier == wantedIdentifier,
                      verifiedKeyboardAssignmentIdentifier == wantedIdentifier,
                      currentIdentifier == wantedIdentifier {
                clearWarning(cause: .selectionFailure)
            } else {
                wantedKeyboardAssignmentGeneration &+= 1
                let generation = wantedKeyboardAssignmentGeneration
                wantedKeyboardAssignmentIdentifier = wantedIdentifier
                _ = applyWantedKeyboardAssignment(
                    wantedIdentifier,
                    generation: generation
                )
            }
        case .unassigned, .unsupported:
            break
        }

        rebuildOutcome()
    }

    /// Internal seam for deterministic external Input Source changes.
    func handleExternalInputSourceChange() {
        guard isStarted, persistenceError == nil, outcome.switchingStatus == .ready else {
            return
        }
        let currentIdentifier = inputSources.currentInputSourceIdentifier
        let previousObserved = observedCurrentInputSourceIdentifier
        let previousVerified = verifiedKeyboardAssignmentIdentifier
        observedCurrentInputSourceIdentifier = currentIdentifier

        if let verified = verifiedKeyboardAssignmentIdentifier,
           currentIdentifier != verified {
            verifiedKeyboardAssignmentIdentifier = nil
        }

        if previousObserved != observedCurrentInputSourceIdentifier
            || previousVerified != verifiedKeyboardAssignmentIdentifier {
            Log.verbose(
                .switching,
                "Observed Input Source is now \(observedCurrentInputSourceIdentifier ?? "none")"
            )
            rebuildOutcome()
        }
    }

    private var activeWarnings: [SwitchingWarning] {
        activeWarningByCause.values.sorted { $0.id < $1.id }
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
            _ = try reevaluateUnavailableKeyboardAssignments()
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
            _ = try reevaluateUnavailableKeyboardAssignments()
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
            _ = reevaluateUnavailableKeyboardAssignments(records: records)
        } catch {
            markPersistenceUnavailable()
            return
        }
        rebuildOutcome()
    }

    private func reconcileWantedAssignmentFromRecords(_ records: [SavedPhysicalKeyboardRecord]) {
        guard let wanted = wantedKeyboardAssignment else {
            return
        }

        let assignment = records
            .first(where: { $0.identityKey == wanted.physicalKeyboardID.rawValue })?
            .keyboardAssignment
        guard let assignment else {
            wantedKeyboardAssignment = nil
            wantedKeyboardAssignmentIdentifier = nil
            verifiedKeyboardAssignmentIdentifier = nil
            clearWarning(cause: .selectionFailure)
            return
        }

        guard assignment.inputSourceIdentifier != wanted.inputSourceIdentifier else {
            return
        }

        wantedKeyboardAssignment = WantedKeyboardAssignment(
            physicalKeyboardID: wanted.physicalKeyboardID,
            inputSourceIdentifier: assignment.inputSourceIdentifier
        )
        wantedKeyboardAssignmentIdentifier = assignment.inputSourceIdentifier
        if verifiedKeyboardAssignmentIdentifier != assignment.inputSourceIdentifier {
            verifiedKeyboardAssignmentIdentifier = nil
        }
        clearWarning(cause: .selectionFailure)
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

    private func applyWantedKeyboardAssignment(
        _ inputSourceIdentifier: String,
        generation: UInt64
    ) -> Bool {
        guard persistenceError == nil else {
            return false
        }
        let keyboardName = physicalKeyboardName(wantedKeyboardAssignment?.physicalKeyboardID)
        guard persistenceError == nil else { return false }
        let verified = inputSources.selectAndVerifyInputSource(identifier: inputSourceIdentifier)
        guard generation == wantedKeyboardAssignmentGeneration else {
            return false
        }

        if verified {
            verifiedKeyboardAssignmentIdentifier = inputSourceIdentifier
            observedCurrentInputSourceIdentifier = inputSourceIdentifier
            clearWarning(cause: .selectionFailure)
            Log.debug(
                .switching,
                "Selected Input Source \(inputSourceIdentifier) for "
                    + "\(keyboardName)"
            )
            return true
        }

        if verifiedKeyboardAssignmentIdentifier == inputSourceIdentifier {
            verifiedKeyboardAssignmentIdentifier = nil
        }
        observedCurrentInputSourceIdentifier = inputSources.currentInputSourceIdentifier
        openWarning(.selectionFailure(inputSourceIdentifier: inputSourceIdentifier))
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
        persistenceError = "Click Retry to read them again."
        physicalKeyboardDiscovery.stopActivationActivityObservation()
        inputSources.stopObservingChanges()
    }

    private func isUnavailable(_ assignment: KeyboardAssignment) -> Bool {
        !KeyboardAssignmentAvailability.isAvailable(
            assignment,
            eligibleInputSources: inputSources.eligibleInputSources
        )
    }

    private func openWarning(_ warning: SwitchingWarning) {
        let isNewEpisode = activeWarningByCause[warning.cause] == nil
        activeWarningByCause[warning.cause] = warning
        if isNewEpisode {
            warningEpisodeCount += 1
        }
    }

    private func clearWarning(cause: SwitchingWarning.Cause) {
        activeWarningByCause.removeValue(forKey: cause)
    }

    private func updateUnavailableReason(
        _ reason: SwitchingUnavailableReason,
        isActive: Bool
    ) {
        var reasons = Set(outcome.temporarilyUnavailableReasons)
        if isActive {
            reasons.insert(reason)
        } else {
            reasons.remove(reason)
        }

        let orderedReasons = SwitchingUnavailableReason.priority.filter { reasons.contains($0) }
        guard orderedReasons != outcome.temporarilyUnavailableReasons else {
            return
        }

        outcome = replacingOutcome(reasons: orderedReasons)
    }

    private func reconcileProtectedState() {
        let protectedState = protectedStateProvider.currentProtectedState()
        var reasons = Set(outcome.temporarilyUnavailableReasons)
        if protectedState.isSecureInputEnabled {
            reasons.insert(.secureInput)
        } else {
            reasons.remove(.secureInput)
        }
        if !protectedState.isProtectedDataAvailable || eventProtectedDataUnavailable {
            reasons.insert(.protectedDataUnavailable)
        } else {
            reasons.remove(.protectedDataUnavailable)
        }

        outcome = replacingOutcome(reasons: SwitchingUnavailableReason.priority.filter { reasons.contains($0) })
    }

    @discardableResult
    private func reevaluateUnavailableKeyboardAssignments() throws -> Bool {
        reevaluateUnavailableKeyboardAssignments(records: try physicalKeyboardRecordStore.allRecords())
    }

    @discardableResult
    private func reevaluateUnavailableKeyboardAssignments(
        records: [SavedPhysicalKeyboardRecord]
    ) -> Bool {
        var changed = false
        let eligibleIdentifiers = Set(inputSources.eligibleInputSources.map(\.identifier))
        let excludedKeys = Set(exclusionStore.allExclusions().map(\.key))
        var remainingUnavailableIDs = Set(
            activeWarningByCause.keys.compactMap { cause -> PhysicalKeyboardRecordID? in
                if case let .unavailableKeyboardAssignment(id) = cause {
                    return id
                }
                return nil
            }
        )

        for record in records {
            guard let assignment = record.keyboardAssignment else {
                continue
            }

            let physicalKeyboardID = record.recordID
            // An excluded device keeps its record, so its warning must not survive.
            guard !excludedKeys.contains(PhysicalKeyboardExclusionKey.key(for: physicalKeyboardID)) else {
                continue
            }
            if KeyboardAssignmentAvailability.isAvailable(
                assignment,
                eligibleIdentifiers: eligibleIdentifiers
            ) {
                if activeWarningByCause[.unavailableKeyboardAssignment(physicalKeyboardID)] != nil {
                    clearWarning(cause: .unavailableKeyboardAssignment(physicalKeyboardID))
                    changed = true
                }
            } else {
                let previous = activeWarningByCause[
                    .unavailableKeyboardAssignment(physicalKeyboardID)
                ]
                openWarning(
                    .unavailableKeyboardAssignment(
                        physicalKeyboardID: physicalKeyboardID,
                        inputSourceIdentifier: assignment.inputSourceIdentifier
                    )
                )
                if previous?.inputSourceIdentifier != assignment.inputSourceIdentifier {
                    changed = true
                }
            }
            remainingUnavailableIDs.remove(physicalKeyboardID)
        }

        for staleID in remainingUnavailableIDs {
            clearWarning(cause: .unavailableKeyboardAssignment(staleID))
            changed = true
        }

        return changed
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
        let mismatch: ActivityTriggeredSwitchingMismatch? = {
            guard case let .assigned(savedAssignment) = activeKeyboard?.assignmentState,
                  let currentIdentifier,
                  currentIdentifier != savedAssignment.inputSourceIdentifier
            else {
                return nil
            }

            guard let currentName = displayName(forInputSourceIdentifier: currentIdentifier),
                  let assignedName = displayName(
                      forInputSourceIdentifier: savedAssignment.inputSourceIdentifier
                  )
            else {
                return nil
            }

            return ActivityTriggeredSwitchingMismatch(
                currentName: currentName,
                assignedName: assignedName
            )
        }()

        let warnings = try activeWarnings.map { warning in
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
            availableActions: availableActions
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
