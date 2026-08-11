import Foundation
import Observation

@MainActor
final class PhysicalKeyboardPresentationResolver {
    private let recordStore: any PhysicalKeyboardRecordStoring
    private let designationStore: any ManualPhysicalKeyboardDesignationStoring
    private let integrityKeyProvider: any InstallationIntegrityKeyProviding

    init(
        recordStore: any PhysicalKeyboardRecordStoring,
        designationStore: any ManualPhysicalKeyboardDesignationStoring,
        integrityKeyProvider: any InstallationIntegrityKeyProviding
    ) {
        self.recordStore = recordStore
        self.designationStore = designationStore
        self.integrityKeyProvider = integrityKeyProvider
    }

    func resolve(_ keyboard: PhysicalKeyboard) -> PhysicalKeyboard {
        guard keyboard.id.isIdentityBased else {
            return keyboard
        }

        let savedRecord = recordStore.record(forIdentityKey: keyboard.id.rawValue)

        if keyboard.isAssignable {
            return keyboard.applying(savedRecord: savedRecord)
        }

        guard
            let designation = designationStore.designation(
                forIdentityKey: keyboard.id.rawValue
            ),
            ManualPhysicalKeyboardDesignationAuthenticator.isAuthentic(
                designation,
                integrityKey: integrityKeyProvider.integrityKey()
            )
        else {
            return keyboard
        }

        return keyboard
            .elevatingWithManualDesignation(confirmedName: designation.confirmedName)
            .applying(savedRecord: savedRecord)
    }
}

/// Deep Activity-Triggered Switching module.
///
/// External callers learn one outcome and seven product operations. Observation,
/// exact selection, recovery, lifecycle, notifications, and adapter details
/// stay inside this module.
@MainActor
@Observable
final class ActivityTriggeredSwitching {
    private(set) var outcome: ActivityTriggeredSwitchingOutcome

    private let permissionProvider: any ListenPermissionProviding
    private let protectedStateProvider: any ProtectedStateProviding
    private let setupStore: any SetupDecisionStoring
    private let physicalKeyboardDiscovery: PhysicalKeyboardDiscovery
    private let inputSources: InputSourceModule
    private let physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring
    private let resolver: PhysicalKeyboardPresentationResolver
    private let diagnosticDataController: any DiagnosticDataControlling
    private let operationalNotifications: OperationalNotifications

    private var isStarted = false
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
    private var discoveryObserverID: UUID?
    private var discoveryRecordObserverID: UUID?
    private var inputSourceObserverID: UUID?
    private var notificationObserverID: UUID?

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

        lastActivePhysicalKeyboard = resolver.resolve(keyboard)
        physicalKeyboardDiscovery.markActive(physicalKeyboardID)
        rebuildOutcome()
    }

    init(
        permissionProvider: any ListenPermissionProviding,
        protectedStateProvider: any ProtectedStateProviding = SystemProtectedStateProvider(),
        setupStore: any SetupDecisionStoring,
        physicalKeyboardDiscovery: PhysicalKeyboardDiscovery,
        inputSources: InputSourceModule,
        physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring,
        designationStore: any ManualPhysicalKeyboardDesignationStoring,
        integrityKeyProvider: any InstallationIntegrityKeyProviding,
        diagnosticDataController: any DiagnosticDataControlling = KeyameleonDiagnosticDataService(
            store: InMemoryDiagnosticDataStore()
        ),
        operationalNotifications: OperationalNotifications = OperationalNotifications()
    ) {
        self.permissionProvider = permissionProvider
        self.protectedStateProvider = protectedStateProvider
        self.setupStore = setupStore
        self.physicalKeyboardDiscovery = physicalKeyboardDiscovery
        self.inputSources = inputSources
        self.physicalKeyboardRecordStore = physicalKeyboardRecordStore
        resolver = PhysicalKeyboardPresentationResolver(
            recordStore: physicalKeyboardRecordStore,
            designationStore: designationStore,
            integrityKeyProvider: integrityKeyProvider
        )
        self.diagnosticDataController = diagnosticDataController
        self.operationalNotifications = operationalNotifications
        observedCurrentInputSourceIdentifier = inputSources.currentInputSourceIdentifier

        let protectedState = protectedStateProvider.currentProtectedState()
        let reasons = Self.unavailableReasons(
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

        operationalNotifications.update(
            listenPermission: permission,
            warnings: [],
            hasKeyboardAssignment: false,
            paused: setupStore.isActivityTriggeredSwitchingPaused
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
        notificationObserverID = operationalNotifications.observe { [weak self] in
            self?.rebuildOutcome()
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
        if let notificationObserverID {
            operationalNotifications.removeObserver(notificationObserverID)
        }
        self.discoveryObserverID = nil
        self.discoveryRecordObserverID = nil
        self.inputSourceObserverID = nil
        self.notificationObserverID = nil
        isStarted = false
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
        _ = reevaluateUnavailableKeyboardAssignments()

        let status = SwitchingStatus.resolve(
            listenPermission: permission,
            isTemporarilyUnavailable: !outcome.temporarilyUnavailableReasons.isEmpty,
            isPaused: setupStore.isActivityTriggeredSwitchingPaused
        )
        recordStatusChange(from: previousStatus, to: status)
        outcome = replacingOutcome(status: status)
        updateObservation(for: status)
        operationalNotifications.update(
            listenPermission: permission,
            warnings: activeWarnings,
            hasKeyboardAssignment: hasKeyboardAssignment,
            paused: setupStore.isActivityTriggeredSwitchingPaused
        )
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
        guard outcome.hasAction(.retryNow),
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
    /// forgotten or explicitly replaced.
    func forgetPhysicalKeyboard(_ physicalKeyboardID: PhysicalKeyboardRecordID) {
        guard physicalKeyboardDiscovery.activePhysicalKeyboardID == physicalKeyboardID else {
            return
        }

        lastActivePhysicalKeyboard = nil
        physicalKeyboardDiscovery.clearActive(if: physicalKeyboardID)
        rebuildOutcome()
    }

    func replaceActivePhysicalKeyboard(
        from oldID: PhysicalKeyboardRecordID,
        to newID: PhysicalKeyboardRecordID
    ) {
        guard physicalKeyboardDiscovery.activePhysicalKeyboardID == oldID else {
            return
        }

        physicalKeyboardDiscovery.markActive(newID)
        lastActivePhysicalKeyboard = physicalKeyboardDiscovery.physicalKeyboards.first {
            $0.id == newID
        }.map(resolver.resolve)
        rebuildOutcome()
    }

    /// Application lifecycle seam. Not part of the product interface.
    func handleLifecycleEvent(_ event: KeyameleonLifecycleEvent) {
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
        guard isStarted, outcome.switchingStatus == .ready else {
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

        inputSources.refresh()
        let physicalKeyboard = resolver.resolve(rawKeyboard)
        let activeChanged = physicalKeyboardDiscovery.activePhysicalKeyboardID != physicalKeyboard.id
        lastActivePhysicalKeyboard = physicalKeyboard
        physicalKeyboardDiscovery.markActive(physicalKeyboard.id)

        if activeChanged {
            diagnosticDataController.record(
                code: .activePhysicalKeyboardChanged,
                identityKey: physicalKeyboard.id.rawValue,
                switchingStatus: nil
            )
        }
        diagnosticDataController.record(
            code: .activationActivityAttributed,
            identityKey: physicalKeyboard.id.rawValue,
            switchingStatus: nil
        )

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
                      currentIdentifier == wantedIdentifier
            {
                clearWarning(cause: .selectionFailure)
                diagnosticDataController.record(
                    code: .inputSourceSelectionCoalesced,
                    identityKey: physicalKeyboard.id.rawValue,
                    switchingStatus: nil
                )
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

        updateOperationalNotifications()
        rebuildOutcome()
    }

    /// Internal seam for deterministic external Input Source changes.
    func handleExternalInputSourceChange() {
        guard isStarted, outcome.switchingStatus == .ready else {
            return
        }

        let currentIdentifier = inputSources.currentInputSourceIdentifier
        let previousObserved = observedCurrentInputSourceIdentifier
        let previousVerified = verifiedKeyboardAssignmentIdentifier
        observedCurrentInputSourceIdentifier = currentIdentifier

        if let verified = verifiedKeyboardAssignmentIdentifier,
           currentIdentifier != verified
        {
            verifiedKeyboardAssignmentIdentifier = nil
        }

        if previousObserved != observedCurrentInputSourceIdentifier
            || previousVerified != verifiedKeyboardAssignmentIdentifier
        {
            rebuildOutcome()
        }
    }

    private var activeWarnings: [SwitchingWarning] {
        activeWarningByCause.values.sorted { $0.id < $1.id }
    }

    private var hasKeyboardAssignment: Bool {
        physicalKeyboardRecordStore.allRecords().contains { $0.keyboardAssignment != nil }
    }

    private func updateObservation(for status: SwitchingStatus) {
        guard isStarted else {
            return
        }

        if status.allowsPhysicalKeyboardDiscovery {
            physicalKeyboardDiscovery.start()
        } else {
            physicalKeyboardDiscovery.stop()
        }

        if status == .ready {
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
        if let activeID = physicalKeyboardDiscovery.activePhysicalKeyboardID,
           let keyboard = physicalKeyboardDiscovery.physicalKeyboards.first(where: {
               $0.id == activeID
           })
        {
            lastActivePhysicalKeyboard = resolver.resolve(keyboard)
        }
        _ = reevaluateUnavailableKeyboardAssignments()
        rebuildOutcome()
    }

    private func handleDiscoveryRecordChange(
        _ change: PhysicalKeyboardDiscoveryRecordChange
    ) {
        switch change {
        case let .connected(physicalKeyboardID):
            diagnosticDataController.record(
                code: .physicalKeyboardConnected,
                identityKey: physicalKeyboardID.rawValue,
                switchingStatus: nil
            )
        case let .disconnected(physicalKeyboardID):
            diagnosticDataController.record(
                code: .physicalKeyboardDisconnected,
                identityKey: physicalKeyboardID.rawValue,
                switchingStatus: nil
            )
        }
    }

    private func handleInputSourceModuleChange() {
        handleExternalInputSourceChange()
        _ = reevaluateUnavailableKeyboardAssignments()
        rebuildOutcome()
    }

    private func handleRecordChange() {
        reconcileWantedAssignmentFromRecords()
        _ = reevaluateUnavailableKeyboardAssignments()
        updateOperationalNotifications()
        rebuildOutcome()
    }

    private func updateOperationalNotifications() {
        operationalNotifications.update(
            listenPermission: lastKnownListenPermission,
            warnings: activeWarnings,
            hasKeyboardAssignment: hasKeyboardAssignment,
            paused: setupStore.isActivityTriggeredSwitchingPaused
        )
    }

    private func reconcileWantedAssignmentFromRecords() {
        guard let wanted = wantedKeyboardAssignment else {
            return
        }

        let assignment = physicalKeyboardRecordStore
            .record(forIdentityKey: wanted.physicalKeyboardID.rawValue)?
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

        diagnosticDataController.record(
            code: .switchingStatusChanged,
            identityKey: nil,
            switchingStatus: current
        )
        if current == .permissionRequired {
            diagnosticDataController.record(
                code: .permissionDenied,
                identityKey: nil,
                switchingStatus: current
            )
        }
    }

    private func applyWantedKeyboardAssignment(
        _ inputSourceIdentifier: String,
        generation: UInt64
    ) -> Bool {
        let verified = inputSources.selectAndVerifyInputSource(identifier: inputSourceIdentifier)
        guard generation == wantedKeyboardAssignmentGeneration else {
            return false
        }

        if verified {
            verifiedKeyboardAssignmentIdentifier = inputSourceIdentifier
            observedCurrentInputSourceIdentifier = inputSourceIdentifier
            clearWarning(cause: .selectionFailure)
            diagnosticDataController.record(
                code: .inputSourceSelectionSucceeded,
                identityKey: wantedKeyboardAssignment?.physicalKeyboardID.rawValue,
                switchingStatus: nil
            )
            return true
        }

        if verifiedKeyboardAssignmentIdentifier == inputSourceIdentifier {
            verifiedKeyboardAssignmentIdentifier = nil
        }
        observedCurrentInputSourceIdentifier = inputSources.currentInputSourceIdentifier
        openWarning(.selectionFailure(inputSourceIdentifier: inputSourceIdentifier))
        diagnosticDataController.record(
            code: .inputSourceSelectionFailed,
            identityKey: wantedKeyboardAssignment?.physicalKeyboardID.rawValue,
            switchingStatus: nil
        )
        return false
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

        let orderedReasons = Self.unavailableReasonPriority.filter { reasons.contains($0) }
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

        outcome = replacingOutcome(
            reasons: Self.unavailableReasonPriority.filter { reasons.contains($0) }
        )
    }

    @discardableResult
    private func reevaluateUnavailableKeyboardAssignments() -> Bool {
        var changed = false
        let eligibleIdentifiers = Set(inputSources.eligibleInputSources.map(\.identifier))
        var remainingUnavailableIDs = Set(
            activeWarningByCause.keys.compactMap { cause -> PhysicalKeyboardRecordID? in
                if case let .unavailableKeyboardAssignment(id) = cause {
                    return id
                }
                return nil
            }
        )

        for record in physicalKeyboardRecordStore.allRecords() {
            guard let assignment = record.keyboardAssignment else {
                continue
            }

            let physicalKeyboardID = record.recordID
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
        let activeKeyboard = activeKeyboardForOutcome()
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

        let warnings = activeWarnings.map { warning in
            ActivityTriggeredSwitchingWarning(
                physicalKeyboardName: warningName(for: warning),
                category: warning.category,
                recoveryAction: warning.recoveryAction
            )
        }

        let availableActions = availableActions(for: outcome.switchingStatus, warnings: warnings)
        outcome = ActivityTriggeredSwitchingOutcome(
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
    }

    private func activeKeyboardForOutcome() -> PhysicalKeyboard? {
        if let activePhysicalKeyboardID = physicalKeyboardDiscovery.activePhysicalKeyboardID,
           let connected = physicalKeyboardDiscovery.physicalKeyboards.first(where: {
               $0.id == activePhysicalKeyboardID
           })
        {
            let resolved = resolver.resolve(connected)
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

    private func warningName(for warning: SwitchingWarning) -> String? {
        guard case let .unavailableKeyboardAssignment(physicalKeyboardID) = warning.cause else {
            return activeKeyboardForOutcome()?.name
        }

        if let keyboard = physicalKeyboardDiscovery.physicalKeyboards.first(where: {
            $0.id == physicalKeyboardID
        }) {
            return resolver.resolve(keyboard).name
        }

        return physicalKeyboardRecordStore.record(
            forIdentityKey: physicalKeyboardID.rawValue
        )?.name
    }

    private func displayName(forInputSourceIdentifier identifier: String) -> String? {
        inputSources.eligibleInputSources.first { $0.identifier == identifier }?.name
    }

    private func availableActions(
        for status: SwitchingStatus,
        warnings: [ActivityTriggeredSwitchingWarning]
    ) -> Set<ActivityTriggeredSwitchingAction> {
        var actions: Set<ActivityTriggeredSwitchingAction>
        switch status {
        case .ready:
            actions = [
                .openSystemSettings,
                .checkAgain,
            ]
        case .permissionRequired:
            actions = [.requestPermission, .openSystemSettings, .checkAgain]
        case .paused:
            actions = [.requestPermission, .openSystemSettings, .checkAgain]
        case .temporarilyUnavailable:
            actions = []
        }

        if setupStore.isActivityTriggeredSwitchingPaused {
            actions.insert(.resume)
        } else {
            actions.insert(.pause)
        }
        if status == .ready,
           warnings.contains(where: { $0.recoveryAction == .retryNow })
        {
            actions.insert(.retryNow)
        }
        return actions
    }

    private func replacingOutcome(
        status: SwitchingStatus? = nil,
        reasons: [SwitchingUnavailableReason]? = nil
    ) -> ActivityTriggeredSwitchingOutcome {
        ActivityTriggeredSwitchingOutcome(
            switchingStatus: status ?? outcome.switchingStatus,
            temporarilyUnavailableReasons: reasons ?? outcome.temporarilyUnavailableReasons,
            activePhysicalKeyboard: outcome.activePhysicalKeyboard,
            currentKeyboardAssignment: outcome.currentKeyboardAssignment,
            currentInputSourceName: outcome.currentInputSourceName,
            mismatch: outcome.mismatch,
            warnings: outcome.warnings,
            availableActions: outcome.availableActions
        )
    }

    private static let unavailableReasonPriority: [SwitchingUnavailableReason] = [
        .sleeping,
        .inactiveSession,
        .secureInput,
        .protectedDataUnavailable,
    ]

    private static func unavailableReasons(
        protectedState: ProtectedStateSnapshot,
        eventProtectedDataUnavailable: Bool
    ) -> [SwitchingUnavailableReason] {
        var reasons = Set<SwitchingUnavailableReason>()
        if protectedState.isSecureInputEnabled {
            reasons.insert(.secureInput)
        }
        if !protectedState.isProtectedDataAvailable || eventProtectedDataUnavailable {
            reasons.insert(.protectedDataUnavailable)
        }
        return unavailableReasonPriority.filter { reasons.contains($0) }
    }
}
