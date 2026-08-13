import Foundation
import Observation

enum GuidedSetupStep: String, Equatable, Sendable {
    case permission
    case assignments
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
        defaults.set(GuidedSetupStep.assignments.rawValue, forKey: Key.guidedSetupStep)
    }

    func setActivityTriggeredSwitchingPaused(_ paused: Bool) {
        defaults.set(paused, forKey: Key.isActivityTriggeredSwitchingPaused)
    }

    func markBuiltInIdentityMigrationEvaluated() {
        defaults.set(true, forKey: Key.hasEvaluatedBuiltInIdentityMigration)
    }

    func resetForUITesting() {
        defaults.removeObject(forKey: Key.hasStartedGuidedSetup)
        defaults.removeObject(forKey: Key.hasCompletedGuidedSetup)
        defaults.removeObject(forKey: Key.guidedSetupStep)
        defaults.removeObject(forKey: Key.isActivityTriggeredSwitchingPaused)
        defaults.removeObject(forKey: Key.hasEvaluatedBuiltInIdentityMigration)
    }
}

/// Presentation model for setup and Physical Keyboard management.
///
/// Activity-Triggered Switching owns switching behavior and exposes one
/// canonical outcome. This model owns guided setup, saved names and
/// Keyboard Assignment editing only.
@MainActor
@Observable
final class KeyameleonSetupModel {
    private(set) var isSetupComplete: Bool
    private(set) var hasStartedGuidedSetup: Bool
    private(set) var guidedSetupStep: GuidedSetupStep
    private(set) var physicalKeyboards: [PhysicalKeyboard] = []
    private(set) var eligibleInputSources: [EligibleInputSource] = []
    private(set) var manualDesignationPhase: ManualPhysicalKeyboardDesignationPhase = .idle
    private(set) var notificationAuthorizationState: OperationalNotificationAuthorizationState
    private(set) var shouldOfferOperationalNotificationSetup: Bool

    let activityTriggeredSwitching: ActivityTriggeredSwitching

    private let setupStore: any SetupDecisionStoring
    private let systemSettingsOpener: any SystemSettingsOpening
    private let physicalKeyboardDiscovery: PhysicalKeyboardDiscovery
    private let inputSources: InputSourceModule
    private let physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring
    private let designationStore: any ManualPhysicalKeyboardDesignationStoring
    private let integrityKeyProvider: any InstallationIntegrityKeyProviding
    private let diagnosticDataController: any DiagnosticDataControlling
    private let operationalNotifications: OperationalNotifications
    private let resolver: PhysicalKeyboardPresentationResolver
    private var lastKnownPhysicalKeyboards: [String: PhysicalKeyboard] = [:]
    private var discoveryObserverID: UUID?
    private var inputSourceObserverID: UUID?
    private var notificationObserverID: UUID?

    init(
        activityTriggeredSwitching: ActivityTriggeredSwitching,
        setupStore: any SetupDecisionStoring,
        systemSettingsOpener: any SystemSettingsOpening,
        physicalKeyboardDiscovery: PhysicalKeyboardDiscovery,
        inputSources: InputSourceModule,
        physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring,
        designationStore: any ManualPhysicalKeyboardDesignationStoring,
        integrityKeyProvider: any InstallationIntegrityKeyProviding,
        diagnosticDataController: any DiagnosticDataControlling,
        operationalNotifications: OperationalNotifications
    ) {
        self.activityTriggeredSwitching = activityTriggeredSwitching
        self.setupStore = setupStore
        self.systemSettingsOpener = systemSettingsOpener
        self.physicalKeyboardDiscovery = physicalKeyboardDiscovery
        self.inputSources = inputSources
        self.physicalKeyboardRecordStore = physicalKeyboardRecordStore
        self.designationStore = designationStore
        self.integrityKeyProvider = integrityKeyProvider
        self.diagnosticDataController = diagnosticDataController
        self.operationalNotifications = operationalNotifications
        resolver = PhysicalKeyboardPresentationResolver(
            recordStore: physicalKeyboardRecordStore,
            designationStore: designationStore,
            integrityKeyProvider: integrityKeyProvider
        )
        isSetupComplete = setupStore.hasCompletedGuidedSetup
        hasStartedGuidedSetup = setupStore.hasStartedGuidedSetup
        guidedSetupStep = setupStore.guidedSetupStep
        notificationAuthorizationState = operationalNotifications.authorizationState
        shouldOfferOperationalNotificationSetup = operationalNotifications.shouldOfferSetup

        discoveryObserverID = physicalKeyboardDiscovery.observeChanges { [weak self] _ in
            self?.advanceManualDesignationSession()
            self?.publishPhysicalKeyboards()
        }
        inputSourceObserverID = inputSources.observeChanges { [weak self] in
            guard let self else {
                return
            }

            eligibleInputSources = inputSources.eligibleInputSources
        }
        notificationObserverID = operationalNotifications.observe { [weak self] in
            guard let self else {
                return
            }

            notificationAuthorizationState = operationalNotifications.authorizationState
            shouldOfferOperationalNotificationSetup = operationalNotifications.shouldOfferSetup
        }

        publishPhysicalKeyboards()
        eligibleInputSources = inputSources.eligibleInputSources
    }

    /// Compatibility composition initializer for focused adapter tests.
    /// Production composition uses the concrete module initializer above.
    convenience init(
        permissionProvider: any ListenPermissionProviding,
        protectedStateProvider: any ProtectedStateProviding = SystemProtectedStateProvider(),
        setupStore: any SetupDecisionStoring,
        systemSettingsOpener: any SystemSettingsOpening,
        physicalKeyboardDiscoverer: any PhysicalKeyboardDiscovering =
            SystemPhysicalKeyboardDiscoverer(),
        inputSourceProvider: any InputSourceProviding = SystemInputSourceProvider(),
        inputSourceSelector: any InputSourceSelecting = SystemInputSourceProvider(),
        physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring =
            InMemoryPhysicalKeyboardRecordStore(),
        physicalKeyboardEventObserver: any PhysicalKeyboardEventObserving =
            NoOpPhysicalKeyboardEventObserver(),
        inputSourceChangeObserver: any InputSourceChangeObserving =
            NoOpInputSourceChangeObserver(),
        designationStore: any ManualPhysicalKeyboardDesignationStoring =
            InMemoryManualPhysicalKeyboardDesignationStore(),
        integrityKeyProvider: any InstallationIntegrityKeyProviding =
            InMemoryInstallationIntegrityKeyProvider(),
        diagnosticDataController: any DiagnosticDataControlling = KeyameleonDiagnosticDataService(
            store: InMemoryDiagnosticDataStore()
        ),
        operationalNotificationProvider: any OperationalNotificationProviding =
            NoOpOperationalNotificationProvider(),
        notificationEpisodeStore: any OperationalNotificationEpisodeStoring =
            InMemoryOperationalNotificationEpisodeStore(),
        notificationSetupStore: any NotificationSetupDecisionStoring =
            InMemoryNotificationSetupDecisionStore()
    ) {
        let composition = KeyameleonProductionFactory.makeActivityTriggeredSwitching(
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
            integrityKeyProvider: integrityKeyProvider,
            diagnosticDataController: diagnosticDataController,
            operationalNotificationProvider: operationalNotificationProvider,
            notificationEpisodeStore: notificationEpisodeStore,
            notificationSetupStore: notificationSetupStore
        )
        self.init(
            activityTriggeredSwitching: composition.activityTriggeredSwitching,
            setupStore: composition.setupStore,
            systemSettingsOpener: systemSettingsOpener,
            physicalKeyboardDiscovery: composition.physicalKeyboardDiscovery,
            inputSources: composition.inputSources,
            physicalKeyboardRecordStore: composition.physicalKeyboardRecordStore,
            designationStore: composition.designationStore,
            integrityKeyProvider: composition.integrityKeyProvider,
            diagnosticDataController: composition.diagnosticDataController,
            operationalNotifications: composition.operationalNotifications
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

    var showsAssignmentSetup: Bool {
        isSetupComplete || guidedSetupStep == .assignments
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

    func refreshNotificationAuthorization() {
        operationalNotifications.refreshAuthorization()
    }

    func requestOperationalNotificationAuthorization() {
        operationalNotifications.requestAlertAuthorization()
    }

    func dismissOperationalNotificationSetup() {
        operationalNotifications.dismissSetupOffer()
    }

    func beginGuidedSetup() {
        guard !hasStartedGuidedSetup else {
            return
        }

        setupStore.markGuidedSetupStarted()
        hasStartedGuidedSetup = true
        guidedSetupStep = setupStore.guidedSetupStep
    }

    func continueToAssignments() {
        setupStore.markGuidedSetupStep(.assignments)
        hasStartedGuidedSetup = true
        guidedSetupStep = .assignments
        activityTriggeredSwitching.checkAgain()
    }

    func finishWithoutAssignments() {
        completeSetup()
    }

    func completeSetup() {
        if !hasStartedGuidedSetup {
            setupStore.markGuidedSetupStarted()
            hasStartedGuidedSetup = true
        }
        if guidedSetupStep != .assignments {
            setupStore.markGuidedSetupStep(.assignments)
            guidedSetupStep = .assignments
        }
        if !isSetupComplete {
            setupStore.markGuidedSetupCompleted()
            isSetupComplete = true
        }
    }

    func openSystemSettings() {
        systemSettingsOpener.openSystemSettings()
    }

    func setPhysicalKeyboardName(
        _ physicalKeyboardID: PhysicalKeyboardRecordID,
        customName: String?
    ) {
        guard let physicalKeyboard = physicalKeyboards.first(where: { $0.id == physicalKeyboardID }),
              physicalKeyboard.isAssignable,
              physicalKeyboard.id.isIdentityBased
        else {
            return
        }

        physicalKeyboardRecordStore.saveName(
            identityKey: physicalKeyboard.id.rawValue,
            productName: physicalKeyboard.productName,
            customName: customName
        )
        publishPhysicalKeyboards()
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
        physicalKeyboardRecordStore.saveAssignment(
            identityKey: physicalKeyboard.id.rawValue,
            productName: physicalKeyboard.productName,
            assignment: assignment
        )
        diagnosticDataController.record(
            code: assignment == nil ? .assignmentRemoved : .assignmentSaved,
            identityKey: physicalKeyboard.id.rawValue,
            switchingStatus: nil
        )
        publishPhysicalKeyboards()
    }

    func canForgetPhysicalKeyboard(_ physicalKeyboardID: PhysicalKeyboardRecordID) -> Bool {
        physicalKeyboardID.isIdentityBased
            && physicalKeyboardRecordStore.record(forIdentityKey: physicalKeyboardID.rawValue) != nil
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
              physicalKeyboardRecordStore.record(forIdentityKey: disconnectedID.rawValue) != nil
        else {
            return
        }

        physicalKeyboardRecordStore.transferRecord(
            fromIdentityKey: disconnectedID.rawValue,
            toIdentityKey: connectedID.rawValue,
            productName: connected.productName
        )
        lastKnownPhysicalKeyboards.removeValue(forKey: disconnectedID.rawValue)
        activityTriggeredSwitching.replaceActivePhysicalKeyboard(
            from: disconnectedID,
            to: connectedID
        )
        publishPhysicalKeyboards()
    }

    func forgetConfirmationMessage(for physicalKeyboardID: PhysicalKeyboardRecordID) -> String {
        guard let physicalKeyboard = physicalKeyboards.first(where: { $0.id == physicalKeyboardID })
        else {
            return ""
        }

        let removedData =
            "This removes the saved Physical Keyboard Name, Keyboard Assignment, Manual Physical Keyboard Designation, and linked Diagnostic Data for \(physicalKeyboard.name)."
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
        guard physicalKeyboards.contains(where: { $0.id == physicalKeyboardID }),
              physicalKeyboardID.isIdentityBased
        else {
            return
        }

        physicalKeyboardRecordStore.deleteRecord(identityKey: physicalKeyboardID.rawValue)
        designationStore.delete(identityKey: physicalKeyboardID.rawValue)
        diagnosticDataController.deleteDiagnosticData(forIdentityKey: physicalKeyboardID.rawValue)
        lastKnownPhysicalKeyboards.removeValue(forKey: physicalKeyboardID.rawValue)
        cancelManualDesignationIfMatching(physicalKeyboardID)
        activityTriggeredSwitching.forgetPhysicalKeyboard(physicalKeyboardID)
        publishPhysicalKeyboards()
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
        designationStore.save(
            SavedManualPhysicalKeyboardDesignation(
                identityKey: recordID.rawValue,
                productName: productName,
                confirmedName: confirmedName,
                authenticationTag: tag
            )
        )
        physicalKeyboardRecordStore.saveName(
            identityKey: recordID.rawValue,
            productName: productName,
            customName: confirmedName
        )
        manualDesignationPhase = .idle
        publishPhysicalKeyboards()
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

    func assignedInputSourceName(for physicalKeyboard: PhysicalKeyboard) -> String? {
        guard let identifier = physicalKeyboard.keyboardAssignment?.inputSourceIdentifier else {
            return nil
        }

        return eligibleInputSources.first { $0.identifier == identifier }?.name
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

    private func advanceManualDesignationSession() {
        switch manualDesignationPhase {
        case .idle, .awaitingNameConfirmation:
            return
        case let .awaitingRemoval(recordID):
            let stillConnected = physicalKeyboardDiscovery.physicalKeyboards.contains {
                $0.id == recordID
            }
            if !stillConnected {
                manualDesignationPhase = .awaitingReturn(recordID)
            }
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
        let activeID = physicalKeyboardDiscovery.activePhysicalKeyboardID
        let discovered = physicalKeyboardDiscovery.physicalKeyboards
        migrateBuiltInRecordIfNeeded(from: discovered)
        let connected = discovered.map { keyboard in
            let published = resolver.resolve(keyboard).markingActive(keyboard.id == activeID)
            if keyboard.id.isIdentityBased {
                lastKnownPhysicalKeyboards[keyboard.id.rawValue] = published.markingActive(false)
            }
            return published
        }

        let connectedIdentityKeys = Set(
            connected.filter(\.id.isIdentityBased).map(\.id.rawValue)
        )
        var disconnected = physicalKeyboardRecordStore
            .allRecords()
            .filter { !connectedIdentityKeys.contains($0.identityKey) }
            .map { savedRecord in
                PhysicalKeyboard
                    .disconnected(from: savedRecord)
                    .markingActive(savedRecord.recordID == activeID)
            }
        let disconnectedIdentityKeys = Set(disconnected.map(\.id.rawValue))

        if let activeID,
           activeID.isIdentityBased,
           !connectedIdentityKeys.contains(activeID.rawValue),
           !disconnectedIdentityKeys.contains(activeID.rawValue),
           let lastKnown = lastKnownPhysicalKeyboards[activeID.rawValue]
        {
            disconnected.append(lastKnown.asDisconnected().markingActive(true))
        }

        physicalKeyboards = PhysicalKeyboardListOrdering.sorted(
            connected + disconnected,
            activeID: activeID
        )
    }

    private func migrateBuiltInRecordIfNeeded(
        from discovered: [PhysicalKeyboard]
    ) {
        guard !setupStore.hasEvaluatedBuiltInIdentityMigration,
              let builtIn = discovered.first(where: \.isBuiltIn)
        else {
            return
        }

        setupStore.markBuiltInIdentityMigrationEvaluated()
        guard let migratedRecord = physicalKeyboardRecordStore.migrateSingleOldBuiltInRecord(
            toIdentityKey: builtIn.id.rawValue,
            productName: builtIn.productName
        ) else {
            return
        }

        // Diagnostic Data keeps a one-way token per identity. Migration does
        // not relink that token to the fixed built-in identity.
        diagnosticDataController.deleteDiagnosticData(
            forIdentityKey: migratedRecord.identityKey
        )
    }
}
