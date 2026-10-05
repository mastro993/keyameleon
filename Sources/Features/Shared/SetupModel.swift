import Foundation
import Observation

enum GuidedSetupStep: String, Equatable, Sendable {
    case permission
    case assignments
    case ready
}

@MainActor
protocol SetupDecisionStoring: AnyObject {
    var hasStartedGuidedSetup: Bool { get }
    var hasCompletedGuidedSetup: Bool { get }
    var guidedSetupStep: GuidedSetupStep { get }
    var isActivityTriggeredSwitchingPaused: Bool { get }
    var hasEvaluatedBuiltInIdentityMigration: Bool { get }

    func markGuidedSetupStarted()
    func markGuidedSetupStep(_ step: GuidedSetupStep)
    func markGuidedSetupCompleted()
    func setActivityTriggeredSwitchingPaused(_ paused: Bool)
    func markBuiltInIdentityMigrationEvaluated()
}

@MainActor
final class UserDefaultsSetupDecisionStore: SetupDecisionStoring {
    private enum Key {
        static let hasStartedGuidedSetup = "keyameleon.guidedSetup.started"
        static let hasCompletedGuidedSetup = "keyameleon.guidedSetup.completed"
        static let guidedSetupStep = "keyameleon.guidedSetup.step"
        static let isActivityTriggeredSwitchingPaused =
            "keyameleon.activityTriggeredSwitching.paused"
        static let hasEvaluatedBuiltInIdentityMigration =
            "keyameleon.builtInIdentityMigration.evaluated"
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

    var guidedSetupStep: GuidedSetupStep {
        guard
            let rawValue = defaults.string(forKey: Key.guidedSetupStep),
            let step = GuidedSetupStep(rawValue: rawValue)
        else {
            return .permission
        }

        return step
    }

    var isActivityTriggeredSwitchingPaused: Bool {
        defaults.bool(forKey: Key.isActivityTriggeredSwitchingPaused)
    }

    var hasEvaluatedBuiltInIdentityMigration: Bool {
        defaults.bool(forKey: Key.hasEvaluatedBuiltInIdentityMigration)
    }

    func markGuidedSetupStarted() {
        defaults.set(true, forKey: Key.hasStartedGuidedSetup)
        if defaults.string(forKey: Key.guidedSetupStep) == nil {
            defaults.set(GuidedSetupStep.permission.rawValue, forKey: Key.guidedSetupStep)
        }
    }

    func markGuidedSetupStep(_ step: GuidedSetupStep) {
        defaults.set(true, forKey: Key.hasStartedGuidedSetup)
        defaults.set(step.rawValue, forKey: Key.guidedSetupStep)
    }

    func markGuidedSetupCompleted() {
        defaults.set(true, forKey: Key.hasStartedGuidedSetup)
        defaults.set(true, forKey: Key.hasCompletedGuidedSetup)
        defaults.set(GuidedSetupStep.ready.rawValue, forKey: Key.guidedSetupStep)
    }

    func setActivityTriggeredSwitchingPaused(_ paused: Bool) {
        defaults.set(paused, forKey: Key.isActivityTriggeredSwitchingPaused)
    }

    func markBuiltInIdentityMigrationEvaluated() {
        defaults.set(true, forKey: Key.hasEvaluatedBuiltInIdentityMigration)
    }
}

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
    private(set) var physicalKeyboards: [PhysicalKeyboard] = []
    private(set) var connectedExcludedKeyboardKeys: Set<String> = []
    private(set) var excludedPhysicalKeyboards: [SavedPhysicalKeyboardExclusion] = []
    private(set) var savedPhysicalKeyboardRecords: [SavedPhysicalKeyboardRecord] = []
    private(set) var eligibleInputSources: [EligibleInputSource] = []
    private(set) var manualDesignationPhase: ManualPhysicalKeyboardDesignationPhase = .idle
    private(set) var isWaitingForListenPermission = false

    private(set) var persistenceError: String?
    /// True while either store cannot be read or written, which is what every
    /// surface reports. The row list and the notice must never disagree.
    var hasPersistenceFailure: Bool {
        persistenceError != nil || activityTriggeredSwitching.persistenceError != nil
    }
    private let savedPhysicalKeyboardChanges: SavedPhysicalKeyboardChanges
    private var savedIdentityKeys: Set<String> = []

    var onGuidedSetupCompleted: ((GuidedSetupCompletionDestination) -> Void)?

    let activityTriggeredSwitching: ActivityTriggeredSwitching

    private let setupStore: any SetupDecisionStoring
    private let systemSettingsOpener: any SystemSettingsOpening
    private let physicalKeyboardDiscovery: PhysicalKeyboardDiscovery
    private let inputSources: InputSourceModule
    private let physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring
    private let designationStore: any ManualPhysicalKeyboardDesignationStoring
    private let exclusionStore: any PhysicalKeyboardExclusionStoring
    private let integrityKeyProvider: any InstallationIntegrityKeyProviding
    private let resolver: PhysicalKeyboardPresentationResolver
    private var lastKnownPhysicalKeyboards: [String: PhysicalKeyboard] = [:]
    private var discoveryObserverID: UUID?
    private var inputSourceObserverID: UUID?
    private var permissionPollTask: Task<Void, Never>?

    init(
        activityTriggeredSwitching: ActivityTriggeredSwitching,
        setupStore: any SetupDecisionStoring,
        systemSettingsOpener: any SystemSettingsOpening,
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
        self.systemSettingsOpener = systemSettingsOpener
        self.physicalKeyboardDiscovery = physicalKeyboardDiscovery
        self.inputSources = inputSources
        self.physicalKeyboardRecordStore = physicalKeyboardRecordStore
        self.designationStore = designationStore
        self.exclusionStore = exclusionStore
        self.integrityKeyProvider = integrityKeyProvider
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
            self?.advanceManualDesignationSession()
            self?.publishPhysicalKeyboards()
        }
        _ = physicalKeyboardDiscovery.observeRecordChanges { [weak self] change in
            self?.noteDesignationDisconnect(change)
        }
        inputSourceObserverID = inputSources.observeChanges { [weak self] in
            guard let self else {
                return
            }

            eligibleInputSources = inputSources.eligibleInputSources
        }

        publishPhysicalKeyboards()
        eligibleInputSources = inputSources.eligibleInputSources
    }

    /// Composition initializer for focused adapter tests.
    /// Production composition uses the concrete module initializer above.
    convenience init(
        permissionProvider: any ListenPermissionProviding,
        protectedStateProvider: any ProtectedStateProviding = SystemProtectedStateProvider(),
        setupStore: any SetupDecisionStoring,
        systemSettingsOpener: any SystemSettingsOpening,
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
            InMemoryInstallationIntegrityKeyProvider()
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
            integrityKeyProvider: integrityKeyProvider
        )
        self.init(
            activityTriggeredSwitching: composition.activityTriggeredSwitching,
            setupStore: composition.setupStore,
            systemSettingsOpener: systemSettingsOpener,
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
        startPermissionWaitIfNeeded()
        advanceIfPermissionGranted()
    }

    func endGuidedSetupPresentation() {
        stopPermissionWait()
    }

    func requestPermission() {
        isWaitingForListenPermission = true
        activityTriggeredSwitching.requestPermission()
        startPermissionWaitIfNeeded()
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
        stopPermissionWait()
        isWaitingForListenPermission = false
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
        stopPermissionWait()
        isWaitingForListenPermission = false
        setupStore.markGuidedSetupCompleted()
        isSetupComplete = true
        onGuidedSetupCompleted?(destination)
    }

    func checkPermissionAgain() {
        activityTriggeredSwitching.checkAgain()
        advanceIfPermissionGranted()
    }

    func openSystemSettings() {
        systemSettingsOpener.openSystemSettings()
    }

    func setPhysicalKeyboardName(
        _ physicalKeyboardID: PhysicalKeyboardRecordID,
        customName: String?
    ) {
        guard persistenceError == nil,
              activityTriggeredSwitching.persistenceError == nil,
              physicalKeyboardID.isIdentityBased else {
            return
        }

        let physicalKeyboard: PhysicalKeyboard
        if let liveKeyboard = physicalKeyboards.first(where: { $0.id == physicalKeyboardID }) {
            guard liveKeyboard.isAssignable else { return }
            physicalKeyboard = liveKeyboard
        } else {
            let records = savedPhysicalKeyboardRecords.filter { $0.recordID == physicalKeyboardID }
            guard records.count == 1,
                  let record = records.first,
                  !record.isBuiltInIdentity,
                  excludedPhysicalKeyboards.contains(where: {
                      $0.key == PhysicalKeyboardExclusionKey.key(for: physicalKeyboardID)
                  })
            else {
                return
            }
            physicalKeyboard = .restored(from: record)
        }

        finishSavedPhysicalKeyboardChange(savedPhysicalKeyboardChanges.perform(
            .rename(keyboard: physicalKeyboard, customName: customName)
        ))
    }

    func setKeyboardAssignment(
        _ physicalKeyboardID: PhysicalKeyboardRecordID,
        inputSourceIdentifier: String?
    ) {
        guard let physicalKeyboard = physicalKeyboards.first(where: { $0.id == physicalKeyboardID }),
              physicalKeyboard.isAssignable,
              physicalKeyboard.id.isIdentityBased
        else {
            return
        }

        let assignment = inputSourceIdentifier.flatMap(KeyboardAssignment.init)
        finishSavedPhysicalKeyboardChange(savedPhysicalKeyboardChanges.perform(
            .assign(keyboard: physicalKeyboard, assignment: assignment)
        ))
    }

    func canForgetPhysicalKeyboard(_ physicalKeyboardID: PhysicalKeyboardRecordID) -> Bool {
        physicalKeyboardID.isIdentityBased
            && savedIdentityKeys.contains(physicalKeyboardID.rawValue)
    }

    func replaceCandidates(
        for physicalKeyboardID: PhysicalKeyboardRecordID
    ) -> [PhysicalKeyboard] {
        guard let physicalKeyboard = physicalKeyboards.first(where: { $0.id == physicalKeyboardID }),
              physicalKeyboard.connectionState == .connected,
              physicalKeyboard.isAssignable,
              physicalKeyboard.id.isIdentityBased
        else {
            return []
        }

        return physicalKeyboards.filter { candidate in
            candidate.connectionState == .disconnected
                && candidate.id.isIdentityBased
                && candidate.id != physicalKeyboardID
        }
    }

    func replaceSavedPhysicalKeyboard(
        _ disconnectedID: PhysicalKeyboardRecordID,
        with connectedID: PhysicalKeyboardRecordID
    ) {
        guard let connected = physicalKeyboards.first(where: { $0.id == connectedID }),
              connected.connectionState == .connected,
              connected.isAssignable,
              connected.id.isIdentityBased,
              let disconnected = physicalKeyboards.first(where: { $0.id == disconnectedID }),
              disconnected.connectionState == .disconnected,
              disconnected.id.isIdentityBased,
              savedIdentityKeys.contains(disconnectedID.rawValue)
        else {
            return
        }

        finishSavedPhysicalKeyboardChange(savedPhysicalKeyboardChanges.perform(
            .replace(old: disconnected, new: connected)
        ))
    }

    func forgetConfirmationMessage(for physicalKeyboardID: PhysicalKeyboardRecordID) -> String {
        guard let physicalKeyboard = physicalKeyboards.first(where: { $0.id == physicalKeyboardID })
        else {
            return ""
        }

        let removedData =
            """
            This removes the saved Physical Keyboard Name, Keyboard Assignment, and \
            Manual Physical Keyboard Designation for \(physicalKeyboard.name).
            """
        let reconnectResult = switch physicalKeyboard.connectionState {
        case .connected:
            "This connected Physical Keyboard reappears as new and unassigned."
        case .disconnected:
            "This disconnected Physical Keyboard disappears."
        }
        return "\(removedData) \(reconnectResult)"
    }

    func replaceConfirmationMessage(
        replacing disconnectedID: PhysicalKeyboardRecordID,
        with connectedID: PhysicalKeyboardRecordID
    ) -> String {
        guard let disconnected = physicalKeyboards.first(where: { $0.id == disconnectedID }),
              let connected = physicalKeyboards.first(where: { $0.id == connectedID })
        else {
            return ""
        }

        return """
        Move the Physical Keyboard Name and Keyboard Assignment from \(disconnected.name) to \(connected.name)? \
        The old saved record is removed. If the old hardware returns later, it appears as new and unassigned.
        """
    }

    func forgetPhysicalKeyboard(_ physicalKeyboardID: PhysicalKeyboardRecordID) {
        guard let physicalKeyboard = physicalKeyboards.first(where: { $0.id == physicalKeyboardID }),
              physicalKeyboardID.isIdentityBased
        else {
            return
        }

        finishSavedPhysicalKeyboardChange(savedPhysicalKeyboardChanges.perform(.forget(keyboard: physicalKeyboard)))
    }

    func canExcludePhysicalKeyboard(_ physicalKeyboardID: PhysicalKeyboardRecordID) -> Bool {
        exclusionKey(for: physicalKeyboardID) != nil
    }

    func excludePhysicalKeyboard(_ physicalKeyboardID: PhysicalKeyboardRecordID) {
        guard let key = exclusionKey(for: physicalKeyboardID),
              let physicalKeyboard = physicalKeyboards.first(where: { $0.id == physicalKeyboardID })
        else {
            return
        }

        Log.debug(.setup, "Excluded \(physicalKeyboard.name) as a Physical Keyboard")
        cancelManualDesignationIfMatching(physicalKeyboardID)
        lastKnownPhysicalKeyboards.removeValue(forKey: physicalKeyboardID.rawValue)
        activityTriggeredSwitching.forgetPhysicalKeyboard(physicalKeyboardID)
        exclusionStore.exclude(SavedPhysicalKeyboardExclusion(key: key, name: physicalKeyboard.name))
        applyExclusionKeysToDiscovery()
    }

    /// Key a person excludes this device by, or nil when it is not excludable.
    ///
    /// The built-in Physical Keyboard takes the nil branch. A connected device keys
    /// by its discovered facts, which is the only way to key a device without a
    /// Physical Keyboard Identity. A saved record keys by its own identity, so a
    /// disconnected Physical Keyboard stays excludable.
    func exclusionKey(for physicalKeyboardID: PhysicalKeyboardRecordID) -> String? {
        guard let physicalKeyboard = physicalKeyboards.first(where: { $0.id == physicalKeyboardID }),
              !physicalKeyboard.isBuiltIn
        else {
            return nil
        }

        return physicalKeyboardDiscovery.exclusionKey(for: physicalKeyboardID)
            ?? (physicalKeyboardID.isIdentityBased
                ? PhysicalKeyboardExclusionKey.key(for: physicalKeyboardID)
                : nil)
    }

    func restorePhysicalKeyboard(exclusionKey: String) {
        guard excludedPhysicalKeyboards.contains(where: { $0.key == exclusionKey }) else {
            return
        }

        Log.debug(.setup, "Restored an excluded device to the Physical Keyboard list")
        exclusionStore.restore(key: exclusionKey)
        applyExclusionKeysToDiscovery()
    }

    func exclusionConfirmationMessage(for physicalKeyboardID: PhysicalKeyboardRecordID) -> String {
        guard let physicalKeyboard = physicalKeyboards.first(where: { $0.id == physicalKeyboardID })
        else {
            return ""
        }

        let effect =
            "Keyameleon stops treating \(physicalKeyboard.name) as a Physical Keyboard. "
            + "It stays visible as excluded and never triggers Activity-Triggered Switching."
        let restore = "You can include it again during onboarding or in Settings."

        guard savedIdentityKeys.contains(physicalKeyboardID.rawValue)
        else {
            return "\(effect) \(restore)"
        }

        return "\(effect) Its saved Physical Keyboard Name and Keyboard Assignment stay saved. \(restore)"
    }

    func canStartManualDesignation(for physicalKeyboardID: PhysicalKeyboardRecordID) -> Bool {
        guard manualDesignationPhase == .idle,
              let physicalKeyboard = physicalKeyboards.first(where: { $0.id == physicalKeyboardID }),
              physicalKeyboard.connectionState == .connected
        else {
            return false
        }

        return ManualPhysicalKeyboardDesignationEvidenceRules.offersDesignation(
            for: physicalKeyboard
        )
    }

    func startManualDesignation(for physicalKeyboardID: PhysicalKeyboardRecordID) {
        guard canStartManualDesignation(for: physicalKeyboardID) else {
            return
        }

        manualDesignationPhase = .awaitingRemoval(physicalKeyboardID)
    }

    func cancelManualDesignation() {
        if savedPhysicalKeyboardChanges.cancelPendingDesignation() {
            persistenceError = nil
        }
        manualDesignationPhase = .idle
    }

    func confirmManualDesignationName(_ name: String) {
        guard case let .awaitingNameConfirmation(recordID, productName) = manualDesignationPhase,
              ManualPhysicalKeyboardDesignationEvidenceRules.acceptsConfirmedName(name),
              ManualPhysicalKeyboardDesignationEvidenceRules.acceptsReturn(
                  connected: physicalKeyboardDiscovery.physicalKeyboards,
                  expectedID: recordID
              ) != nil
        else {
            return
        }

        let confirmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let tag = ManualPhysicalKeyboardDesignationAuthenticator.authenticationTag(
            identityKey: recordID.rawValue,
            productName: productName,
            confirmedName: confirmedName,
            integrityKey: integrityKeyProvider.integrityKey()
        )
        let designation = SavedManualPhysicalKeyboardDesignation(
            identityKey: recordID.rawValue,
            productName: productName,
            confirmedName: confirmedName,
            authenticationTag: tag
        )
        finishSavedPhysicalKeyboardChange(savedPhysicalKeyboardChanges.perform(.designate(designation)))
    }

    func manualDesignationStatusText() -> String? {
        switch manualDesignationPhase {
        case .idle:
            nil
        case .awaitingRemoval:
            "Unplug or turn off this Physical Keyboard, then return it."
        case .awaitingReturn:
            "Return the same Physical Keyboard to continue."
        case .awaitingNameConfirmation:
            "Confirm the Physical Keyboard Name to save Manual Physical Keyboard Designation."
        }
    }

    func assignedInputSource(for physicalKeyboard: PhysicalKeyboard) -> EligibleInputSource? {
        guard let identifier = physicalKeyboard.keyboardAssignment?.inputSourceIdentifier else {
            return nil
        }

        return eligibleInputSources.first { $0.identifier == identifier }
    }

    func assignedInputSourceName(for physicalKeyboard: PhysicalKeyboard) -> String? {
        assignedInputSource(for: physicalKeyboard)?.name
    }

    func filteredInputSources(matching query: String) -> [EligibleInputSource] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return eligibleInputSources
        }

        return eligibleInputSources.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private func cancelManualDesignationIfMatching(_ physicalKeyboardID: PhysicalKeyboardRecordID) {
        switch manualDesignationPhase {
        case .idle:
            return
        case let .awaitingRemoval(id),
            let .awaitingReturn(id),
            let .awaitingNameConfirmation(id, _):
            if id == physicalKeyboardID {
                manualDesignationPhase = .idle
            }
        }
    }

    /// Leave is a real disconnect, never an empty catalog.
    ///
    /// Activity-Triggered Switching clears the catalog on sleep, lock, secure
    /// input, and pause. Those publications must not advance the session.
    private func noteDesignationDisconnect(_ change: PhysicalKeyboardDiscoveryRecordChange) {
        guard case let .disconnected(physicalKeyboardID, _) = change else {
            return
        }

        guard case let .awaitingRemoval(recordID) = manualDesignationPhase else {
            return
        }

        guard physicalKeyboardID == recordID else {
            return
        }

        manualDesignationPhase = .awaitingReturn(recordID)
    }

    private func advanceManualDesignationSession() {
        switch manualDesignationPhase {
        case .idle, .awaitingRemoval, .awaitingNameConfirmation:
            return
        case let .awaitingReturn(recordID):
            let connected = physicalKeyboardDiscovery.physicalKeyboards
            if let returned = ManualPhysicalKeyboardDesignationEvidenceRules.acceptsReturn(
                connected: connected,
                expectedID: recordID
            ) {
                manualDesignationPhase = .awaitingNameConfirmation(
                    recordID,
                    productName: returned.productName
                )
            } else if connected.contains(where: { $0.id == recordID }) {
                manualDesignationPhase = .idle
            }
        }
    }

    private func publishPhysicalKeyboards() {
        connectedExcludedKeyboardKeys = physicalKeyboardDiscovery.connectedExcludedKeys
        do {
            try readPhysicalKeyboards()
            if !savedPhysicalKeyboardChanges.hasPendingChange { persistenceError = nil }
        } catch {
            if !savedPhysicalKeyboardChanges.hasPendingChange {
                persistenceError = "Saved Physical Keyboards are unavailable. "
                    + "Check available disk space and access to your user Library, then retry."
            }
        }
    }

    private func readPhysicalKeyboards() throws {
        let activeID = physicalKeyboardDiscovery.activePhysicalKeyboardID
        let discovered = physicalKeyboardDiscovery.physicalKeyboards
        try migrateBuiltInRecordIfNeeded(from: discovered)
        let savedRecords = try physicalKeyboardRecordStore.allRecords()
        var knownKeyboards = lastKnownPhysicalKeyboards
        let connected = try discovered.map { keyboard in
            let published = try resolver.resolve(keyboard).markingActive(keyboard.id == activeID)
            if keyboard.id.isIdentityBased {
                knownKeyboards[keyboard.id.rawValue] = published.markingActive(false)
            }
            return published
        }

        excludedPhysicalKeyboards = exclusionStore.allExclusions()
        let excludedKeys = Set(excludedPhysicalKeyboards.map(\.key))

        let connectedIdentityKeys = Set(
            connected.filter(\.id.isIdentityBased).map(\.id.rawValue)
        )
        var disconnected = savedRecords
            .filter {
                !connectedIdentityKeys.contains($0.identityKey)
                    && !excludedKeys.contains(PhysicalKeyboardExclusionKey.key(for: $0.recordID))
            }
            .map { savedRecord in
                PhysicalKeyboard
                    .restored(from: savedRecord)
                    .markingActive(savedRecord.recordID == activeID)
            }
        let disconnectedIdentityKeys = Set(disconnected.map(\.id.rawValue))

        if let activeID,
           activeID.isIdentityBased,
           !excludedKeys.contains(PhysicalKeyboardExclusionKey.key(for: activeID)),
           !connectedIdentityKeys.contains(activeID.rawValue),
           !disconnectedIdentityKeys.contains(activeID.rawValue),
           let lastKnown = lastKnownPhysicalKeyboards[activeID.rawValue] {
            disconnected.append(lastKnown.asDisconnected().markingActive(true))
        }

        lastKnownPhysicalKeyboards = knownKeyboards
        savedIdentityKeys = Set(savedRecords.map(\.identityKey))
        savedPhysicalKeyboardRecords = savedRecords
        physicalKeyboards = PhysicalKeyboardListOrdering.sorted(
            connected + disconnected
        )
    }

    private func applyExclusionKeysToDiscovery() {
        physicalKeyboardDiscovery.setExcludedKeys(
            Set(exclusionStore.allExclusions().map(\.key))
        )
    }

    private func migrateBuiltInRecordIfNeeded(
        from discovered: [PhysicalKeyboard]
    ) throws {
        guard !setupStore.hasEvaluatedBuiltInIdentityMigration,
              let builtIn = discovered.first(where: \.isBuiltIn)
        else {
            return
        }

        let migratedRecord = try physicalKeyboardRecordStore.migrateSingleOldBuiltInRecord(
            toIdentityKey: builtIn.id.rawValue,
            productName: builtIn.productName
        )
        setupStore.markBuiltInIdentityMigrationEvaluated()
        if migratedRecord != nil {
            Log.debug(
                .setup,
                "Migrated the saved record to the built-in Physical Keyboard"
            )
        }
    }

    func retryPersistenceOperation() {
        let result = savedPhysicalKeyboardChanges.retry()
        if case .nothingPending = result {
            publishPhysicalKeyboards()
        } else {
            finishSavedPhysicalKeyboardChange(result)
        }
        activityTriggeredSwitching.retryPersistenceRead()
    }

    private func finishSavedPhysicalKeyboardChange(_ result: SavedPhysicalKeyboardChangeResult) {
        switch result {
        case let .committed(change):
            persistenceError = nil
            switch change {
            case .rename:
                break
            case let .assign(keyboard, assignment):
                Log.debug(
                    .setup,
                    assignment == nil
                        ? "Keyboard Assignment removed for \(keyboard.name)"
                        : "Keyboard Assignment saved for \(keyboard.name)"
                )
            case let .replace(old, new):
                Log.debug(.setup, "Moved the saved Physical Keyboard record to \(old.name)")
                lastKnownPhysicalKeyboards.removeValue(forKey: old.id.rawValue)
                activityTriggeredSwitching.replaceActivePhysicalKeyboard(from: old.id, to: new.id)
            case let .forget(keyboard):
                Log.debug(.setup, "Forgot Physical Keyboard (\(keyboard.name))")
                lastKnownPhysicalKeyboards.removeValue(forKey: keyboard.id.rawValue)
                cancelManualDesignationIfMatching(keyboard.id)
                activityTriggeredSwitching.forgetPhysicalKeyboard(keyboard.id)
            case .designate:
                manualDesignationPhase = .idle
            }
            publishPhysicalKeyboards()
        case .failed:
            persistenceError = "Your change was not saved. Previous saved records are unchanged. "
                + "Check available disk space and access to your user Library, then retry."
        case .blocked, .nothingPending:
            break
        }
    }

    private func startPermissionWaitIfNeeded() {
        guard !isSetupComplete, guidedSetupStep == .permission else {
            stopPermissionWait()
            return
        }
        guard permissionPollTask == nil else {
            return
        }

        // ponytail: IOHIDCheckAccess has no change notification. 1s poll while
        // the permission step is visible; subscribe if Apple adds a callback.
        permissionPollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                guard let self, !Task.isCancelled else {
                    return
                }

                self.activityTriggeredSwitching.checkAgain()
                self.advanceIfPermissionGranted()
            }
        }
    }

    private func stopPermissionWait() {
        permissionPollTask?.cancel()
        permissionPollTask = nil
    }
}
