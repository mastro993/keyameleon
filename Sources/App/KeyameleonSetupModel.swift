import Foundation
import Combine

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

    func markGuidedSetupStarted()
    func markGuidedSetupStep(_ step: GuidedSetupStep)
    func markGuidedSetupCompleted()
    func setActivityTriggeredSwitchingPaused(_ paused: Bool)
}

@MainActor
final class UserDefaultsSetupDecisionStore: SetupDecisionStoring {
    private enum Key {
        static let hasStartedGuidedSetup = "keyameleon.guidedSetup.started"
        static let hasCompletedGuidedSetup = "keyameleon.guidedSetup.completed"
        static let guidedSetupStep = "keyameleon.guidedSetup.step"
        static let isActivityTriggeredSwitchingPaused =
            "keyameleon.activityTriggeredSwitching.paused"
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

    func resetForUITesting() {
        defaults.removeObject(forKey: Key.hasStartedGuidedSetup)
        defaults.removeObject(forKey: Key.hasCompletedGuidedSetup)
        defaults.removeObject(forKey: Key.guidedSetupStep)
        defaults.removeObject(forKey: Key.isActivityTriggeredSwitchingPaused)
    }
}

@MainActor
final class KeyameleonSetupModel: ObservableObject {
    @Published private(set) var switchingStatus: SwitchingStatus
    @Published private(set) var temporarilyUnavailableReasons: [SwitchingUnavailableReason] = []
    @Published private(set) var isSetupComplete: Bool
    @Published private(set) var hasStartedGuidedSetup: Bool
    @Published private(set) var guidedSetupStep: GuidedSetupStep
    @Published private(set) var physicalKeyboards: [PhysicalKeyboard] = []
    @Published private(set) var eligibleInputSources: [EligibleInputSource] = []
    /// Not persisted across app restart. Nil until first Activation Activity.
    @Published private(set) var activePhysicalKeyboardID: PhysicalKeyboardRecordID?
    /// Last Keyboard Assignment verified active via exact identifier readback.
    @Published private(set) var verifiedKeyboardAssignmentIdentifier: String?
    /// Monotonic wanted Keyboard Assignment generation. Bumps only when a new select is needed.
    @Published private(set) var wantedKeyboardAssignmentGeneration: UInt64 = 0
    /// Exact identifier for the current wanted Keyboard Assignment generation.
    @Published private(set) var wantedKeyboardAssignmentIdentifier: String?
    /// Last observed current Input Source (own select or external change). Not persisted.
    @Published private(set) var observedCurrentInputSourceIdentifier: String?
    @Published private(set) var inputSourceSelectionRequestCount = 0
    /// Number of times a new warning cause became active. Not one per Physical Keyboard Event.
    @Published private(set) var warningEpisodeCount = 0
    /// One warning per active cause. Plain failure category + recovery action only.
    @Published private(set) var activeWarnings: [SwitchingWarning] = []
    /// Latest wanted Keyboard Assignment for Retry Now (Physical Keyboard + identifier).
    @Published private(set) var wantedKeyboardAssignment: WantedKeyboardAssignment?
    @Published private(set) var manualDesignationPhase: ManualPhysicalKeyboardDesignationPhase = .idle
    /// Persists across restart. Pause only Activity-Triggered Switching.
    @Published private(set) var isActivityTriggeredSwitchingPaused: Bool

    private let permissionProvider: any ListenPermissionProviding
    private let protectedStateProvider: any ProtectedStateProviding
    private let setupStore: any SetupDecisionStoring
    private let systemSettingsOpener: any SystemSettingsOpening
    private let physicalKeyboardDiscoverer: any PhysicalKeyboardDiscovering
    private let inputSourceProvider: any InputSourceProviding
    private let inputSourceSelector: any InputSourceSelecting
    private let physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring
    private let physicalKeyboardEventObserver: any PhysicalKeyboardEventObserving
    private let inputSourceChangeObserver: any InputSourceChangeObserving
    private let designationStore: any ManualPhysicalKeyboardDesignationStoring
    private let integrityKeyProvider: any InstallationIntegrityKeyProviding
    private let diagnosticDataController: any DiagnosticDataControlling
    private var physicalKeyboardCatalog = PhysicalKeyboardCatalog()
    private var lastKnownPhysicalKeyboards: [String: PhysicalKeyboard] = [:]
    private var isDiscoveryStarted = false
    private var isEventObservationStarted = false
    private var isInputSourceChangeObservationStarted = false
    private var eventProtectedDataUnavailable = false
    private var activeWarningByCause: [SwitchingWarning.Cause: SwitchingWarning] = [:]

    var onChange: (@MainActor () -> Void)?

    var canObservePhysicalKeyboards: Bool {
        switchingStatus.allowsActivityTriggeredSwitching
    }

    var canRequestInputSources: Bool {
        switchingStatus.allowsActivityTriggeredSwitching
    }

    var canDiscoverPhysicalKeyboards: Bool {
        switchingStatus.allowsPhysicalKeyboardDiscovery
    }

    var temporaryUnavailableReason: SwitchingUnavailableReason? {
        temporarilyUnavailableReasons.first
    }

    var showsAssignmentSetup: Bool {
        isSetupComplete || guidedSetupStep == .assignments
    }

    var activePhysicalKeyboard: PhysicalKeyboard? {
        guard let activePhysicalKeyboardID else {
            return nil
        }

        return physicalKeyboards.first { $0.id == activePhysicalKeyboardID }
    }

    var activePhysicalKeyboardMenuValue: String {
        activePhysicalKeyboard?.name ?? KeyameleonAppMetadata.noActivityObservedYet
    }

    var activeKeyboardAssignmentMenuValue: String {
        guard let activePhysicalKeyboard else {
            return KeyameleonAppMetadata.menuValueUnavailable
        }

        switch activePhysicalKeyboard.assignmentState {
        case .unassigned:
            return "Unassigned"
        case .assigned:
            return assignmentDisplayName(for: activePhysicalKeyboard)
                ?? "Unavailable Keyboard Assignment"
        case let .unsupported(reason):
            return "Unsupported — \(reason.displayName)"
        }
    }

    var currentInputSourceMenuValue: String {
        if let identifier = observedCurrentInputSourceIdentifier
            ?? inputSourceSelector.currentInputSourceIdentifier()
        {
            return displayName(forInputSourceIdentifier: identifier)
        }

        return KeyameleonAppMetadata.menuValueUnavailable
    }

    /// Item conditions that need user action. Global status stays separate.
    var menuFirstActionItems: [MenuFirstActionItem] {
        physicalKeyboards.compactMap { physicalKeyboard in
            switch physicalKeyboard.assignmentState {
            case .unassigned:
                .unassigned(physicalKeyboardName: physicalKeyboard.name)
            case .assigned:
                if assignmentDisplayName(for: physicalKeyboard) == nil {
                    .unavailableKeyboardAssignment(physicalKeyboardName: physicalKeyboard.name)
                } else {
                    nil
                }
            case .unsupported:
                nil
            }
        }
    }

    var hasItemConditionsNeedingAction: Bool {
        !menuFirstActionItems.isEmpty || !isSetupComplete || activeInputSourceMismatch != nil
    }

    var menuBarIconMark: MenuBarIconMark {
        MenuBarIconMark.resolve(
            switchingStatus: switchingStatus,
            hasItemConditionsNeedingAction: hasItemConditionsNeedingAction
        )
    }

    /// Current vs assigned when Active Physical Keyboard assignment differs from observed current.
    var activeInputSourceMismatch: InputSourceMismatchPresentation? {
        guard let activePhysicalKeyboard,
              case let .assigned(assignment) = activePhysicalKeyboard.assignmentState,
              let currentIdentifier = observedCurrentInputSourceIdentifier,
              currentIdentifier != assignment.inputSourceIdentifier
        else {
            return nil
        }

        return InputSourceMismatchPresentation(
            currentName: displayName(forInputSourceIdentifier: currentIdentifier),
            assignedName: displayName(forInputSourceIdentifier: assignment.inputSourceIdentifier),
            restorationExplanation: KeyameleonAppMetadata.inputSourceRestoresAfterActivation
        )
    }

    init(
        permissionProvider: any ListenPermissionProviding,
        protectedStateProvider: any ProtectedStateProviding = SystemProtectedStateProvider(),
        setupStore: any SetupDecisionStoring,
        systemSettingsOpener: any SystemSettingsOpening,
        physicalKeyboardDiscoverer: any PhysicalKeyboardDiscovering = SystemPhysicalKeyboardDiscoverer(),
        inputSourceProvider: any InputSourceProviding = SystemInputSourceProvider(),
        inputSourceSelector: any InputSourceSelecting = SystemInputSourceProvider(),
        physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring = InMemoryPhysicalKeyboardRecordStore(),
        physicalKeyboardEventObserver: any PhysicalKeyboardEventObserving = NoOpPhysicalKeyboardEventObserver(),
        inputSourceChangeObserver: any InputSourceChangeObserving = NoOpInputSourceChangeObserver(),
        designationStore: any ManualPhysicalKeyboardDesignationStoring =
            InMemoryManualPhysicalKeyboardDesignationStore(),
        integrityKeyProvider: any InstallationIntegrityKeyProviding =
            InMemoryInstallationIntegrityKeyProvider(),
        diagnosticDataController: any DiagnosticDataControlling = KeyameleonDiagnosticDataService(
            store: InMemoryDiagnosticDataStore()
        )
    ) {
        self.permissionProvider = permissionProvider
        self.protectedStateProvider = protectedStateProvider
        self.setupStore = setupStore
        self.systemSettingsOpener = systemSettingsOpener
        self.physicalKeyboardDiscoverer = physicalKeyboardDiscoverer
        self.inputSourceProvider = inputSourceProvider
        self.inputSourceSelector = inputSourceSelector
        self.physicalKeyboardRecordStore = physicalKeyboardRecordStore
        self.physicalKeyboardEventObserver = physicalKeyboardEventObserver
        self.inputSourceChangeObserver = inputSourceChangeObserver
        self.designationStore = designationStore
        self.integrityKeyProvider = integrityKeyProvider
        self.diagnosticDataController = diagnosticDataController
        self.isActivityTriggeredSwitchingPaused = setupStore.isActivityTriggeredSwitchingPaused
        self.isSetupComplete = setupStore.hasCompletedGuidedSetup
        self.hasStartedGuidedSetup = setupStore.hasStartedGuidedSetup
        self.guidedSetupStep = setupStore.guidedSetupStep

        let initialProtectedState = protectedStateProvider.currentProtectedState()
        let initialUnavailableReasons = Self.unavailableReasons(
            protectedState: initialProtectedState,
            eventProtectedDataUnavailable: false
        )
        self.temporarilyUnavailableReasons = initialUnavailableReasons
        self.switchingStatus = SwitchingStatus.resolve(
            listenPermission: permissionProvider.checkListenPermission(),
            isTemporarilyUnavailable: !initialUnavailableReasons.isEmpty,
            isPaused: setupStore.isActivityTriggeredSwitchingPaused
        )
    }

    func refreshPermission() {
        reconcileProtectedState()
        applySwitchingStatus(
            listenPermission: permissionProvider.checkListenPermission()
        )
        refreshInputSources()
        refreshObservedCurrentInputSource(publish: false)
        updatePhysicalKeyboardDiscovery()
        updatePhysicalKeyboardEventObservation()
        updateInputSourceChangeObservation()
    }

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

        refreshPermission()
    }

    func pauseActivityTriggeredSwitching() {
        guard !isActivityTriggeredSwitchingPaused else {
            return
        }

        isActivityTriggeredSwitchingPaused = true
        setupStore.setActivityTriggeredSwitchingPaused(true)
        applySwitchingStatus(
            listenPermission: permissionProvider.checkListenPermission()
        )
        updatePhysicalKeyboardDiscovery()
        updatePhysicalKeyboardEventObservation()
        updateInputSourceChangeObservation()
        onChange?()
    }

    /// Clears pause, rechecks listen permission, then starts observation only when Ready.
    func resumeActivityTriggeredSwitching() {
        guard isActivityTriggeredSwitchingPaused else {
            return
        }

        isActivityTriggeredSwitchingPaused = false
        setupStore.setActivityTriggeredSwitchingPaused(false)
        applySwitchingStatus(
            listenPermission: permissionProvider.checkListenPermission()
        )
        refreshInputSources()
        refreshObservedCurrentInputSource(publish: false)
        updatePhysicalKeyboardDiscovery()
        updatePhysicalKeyboardEventObservation()
        updateInputSourceChangeObservation()
        onChange?()
    }

    /// Serial activity consumer entry. Observation order only.
    func handlePhysicalKeyboardEvent(_ event: PhysicalKeyboardEvent) {
        let protectedState = protectedStateProvider.currentProtectedState()
        if protectedState.isSecureInputEnabled || !protectedState.isProtectedDataAvailable {
            // Positive public-API evidence stops processing. Missing activity never does.
            refreshPermission()
            return
        }

        guard switchingStatus.allowsActivityTriggeredSwitching else {
            return
        }

        guard ActivationActivityClassification.isActivationActivity(event) else {
            return
        }

        guard let attributed = physicalKeyboardCatalog.physicalKeyboard(forServiceID: event.serviceID)
        else {
            return
        }

        // Keep eligible Input Sources current so exact-identifier return can end unavailable.
        refreshInputSources()

        // Resolve designation elevation + saved assignment onto the catalog record.
        let physicalKeyboard = resolvePublishedPhysicalKeyboard(attributed)

        let activeChanged = activePhysicalKeyboardID != physicalKeyboard.id
        if activeChanged {
            activePhysicalKeyboardID = physicalKeyboard.id
            diagnosticDataController.record(
                code: .activePhysicalKeyboardChanged,
                identityKey: physicalKeyboard.id.rawValue,
                switchingStatus: nil
            )
        }

        // Session-only detailed marker; ignored in default recording mode.
        diagnosticDataController.record(
            code: .activationActivityAttributed,
            identityKey: physicalKeyboard.id.rawValue,
            switchingStatus: nil
        )

        var didVerify = false
        var didUpdateWanted = false
        var didStateChange = false

        switch physicalKeyboard.assignmentState {
        case let .assigned(assignment):
            let wantedIdentifier = assignment.inputSourceIdentifier
            let currentIdentifier = inputSourceSelector.currentInputSourceIdentifier()
            observedCurrentInputSourceIdentifier = currentIdentifier

            // Newer assigned Activation Activity replaces older wanted state for Retry Now.
            wantedKeyboardAssignment = WantedKeyboardAssignment(
                physicalKeyboardID: physicalKeyboard.id,
                inputSourceIdentifier: wantedIdentifier
            )

            if isUnavailable(assignment) {
                // Keep saved assignment. Never select a substitute.
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
                didUpdateWanted = true
                didStateChange = true
                break
            }

            // Coalesce when this exact Keyboard Assignment is already wanted and verified.
            if wantedKeyboardAssignmentIdentifier == wantedIdentifier,
               verifiedKeyboardAssignmentIdentifier == wantedIdentifier,
               currentIdentifier == wantedIdentifier
            {
                clearWarning(cause: .selectionFailure)
                diagnosticDataController.record(
                    code: .inputSourceSelectionCoalesced,
                    identityKey: physicalKeyboard.id.rawValue,
                    switchingStatus: nil
                )
                break
            }

            // Newer assigned Activation Activity replaces older wanted state.
            wantedKeyboardAssignmentGeneration &+= 1
            let generation = wantedKeyboardAssignmentGeneration
            wantedKeyboardAssignmentIdentifier = wantedIdentifier
            didUpdateWanted = true

            if applyWantedKeyboardAssignment(
                wantedIdentifier,
                generation: generation
            ) {
                didVerify = true
            }
            didStateChange = true
        case .unassigned, .unsupported:
            // No Input Source request for unassigned or unsupported Physical Keyboards.
            break
        }

        if activeChanged || didVerify || didUpdateWanted || didStateChange {
            publishPhysicalKeyboards()
            onChange?()
        }
    }

    /// Explicit recovery. Retries the current wanted Keyboard Assignment. No timed retry loop.
    func retryNow() {
        guard switchingStatus.allowsActivityTriggeredSwitching else {
            return
        }

        guard let wanted = wantedKeyboardAssignment else {
            return
        }

        guard
            let assignment = KeyboardAssignment(inputSourceIdentifier: wanted.inputSourceIdentifier)
        else {
            return
        }

        refreshInputSources()

        if isUnavailable(assignment) {
            clearWarning(cause: .selectionFailure)
            openWarning(
                .unavailableKeyboardAssignment(
                    physicalKeyboardID: wanted.physicalKeyboardID,
                    inputSourceIdentifier: wanted.inputSourceIdentifier
                )
            )
            publishPhysicalKeyboards()
            onChange?()
            return
        }

        wantedKeyboardAssignmentGeneration &+= 1
        let generation = wantedKeyboardAssignmentGeneration
        wantedKeyboardAssignmentIdentifier = wanted.inputSourceIdentifier
        _ = applyWantedKeyboardAssignment(wanted.inputSourceIdentifier, generation: generation)
        publishPhysicalKeyboards()
        onChange?()
    }

    func isUnavailableKeyboardAssignment(for physicalKeyboardID: PhysicalKeyboardRecordID) -> Bool {
        guard
            let physicalKeyboard = physicalKeyboards.first(where: { $0.id == physicalKeyboardID }),
            let assignment = physicalKeyboard.keyboardAssignment
        else {
            return false
        }

        return isUnavailable(assignment)
    }

    /// External Input Source selection: keep it, never fight, refresh observed current only.
    func handleExternalInputSourceChange() {
        guard switchingStatus.allowsActivityTriggeredSwitching else {
            return
        }

        let currentIdentifier = inputSourceSelector.currentInputSourceIdentifier()
        let previousObserved = observedCurrentInputSourceIdentifier
        let previousVerified = verifiedKeyboardAssignmentIdentifier

        observedCurrentInputSourceIdentifier = currentIdentifier

        if let verified = verifiedKeyboardAssignmentIdentifier,
           currentIdentifier != verified
        {
            // External actor owns Input Source until later assigned Activation Activity.
            verifiedKeyboardAssignmentIdentifier = nil
        }

        if previousObserved != observedCurrentInputSourceIdentifier
            || previousVerified != verifiedKeyboardAssignmentIdentifier
        {
            onChange?()
        }
    }

    func requestPermission() {
        guard switchingStatus != .ready else {
            return
        }

        _ = permissionProvider.requestListenPermission()
        refreshPermission()
    }

    func beginGuidedSetup() {
        guard !hasStartedGuidedSetup else {
            return
        }

        setupStore.markGuidedSetupStarted()
        hasStartedGuidedSetup = true
        guidedSetupStep = setupStore.guidedSetupStep
        onChange?()
    }

    func continueToAssignments() {
        setupStore.markGuidedSetupStep(.assignments)
        hasStartedGuidedSetup = true
        guidedSetupStep = .assignments
        refreshPermission()
        onChange?()
    }

    func finishWithoutAssignments() {
        completeSetup()
    }

    func completeSetup() {
        var changed = false

        if !hasStartedGuidedSetup {
            setupStore.markGuidedSetupStarted()
            hasStartedGuidedSetup = true
            changed = true
        }

        if guidedSetupStep != .assignments {
            setupStore.markGuidedSetupStep(.assignments)
            guidedSetupStep = .assignments
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
        onChange?()
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

        let assignment = inputSourceIdentifier.flatMap {
            KeyboardAssignment(inputSourceIdentifier: $0)
        }

        // Saving a Keyboard Assignment never requests an Input Source.
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

        clearWarning(cause: .unavailableKeyboardAssignment(physicalKeyboardID))

        if wantedKeyboardAssignment?.physicalKeyboardID == physicalKeyboardID {
            // Assignment change invalidates prior selection-failure for this wanted state.
            clearWarning(cause: .selectionFailure)
            if let assignment {
                wantedKeyboardAssignment = WantedKeyboardAssignment(
                    physicalKeyboardID: physicalKeyboardID,
                    inputSourceIdentifier: assignment.inputSourceIdentifier
                )
                wantedKeyboardAssignmentIdentifier = assignment.inputSourceIdentifier
            } else {
                wantedKeyboardAssignment = nil
                wantedKeyboardAssignmentIdentifier = nil
            }
        }

        if let assignment, isUnavailable(assignment) {
            openWarning(
                .unavailableKeyboardAssignment(
                    physicalKeyboardID: physicalKeyboardID,
                    inputSourceIdentifier: assignment.inputSourceIdentifier
                )
            )
        }

        if verifiedKeyboardAssignmentIdentifier != nil,
           verifiedKeyboardAssignmentIdentifier != assignment?.inputSourceIdentifier
        {
            verifiedKeyboardAssignmentIdentifier = nil
        }

        publishPhysicalKeyboards()
        onChange?()
    }

    func noteActivationActivity(for physicalKeyboardID: PhysicalKeyboardRecordID) {
        guard physicalKeyboards.contains(where: { $0.id == physicalKeyboardID }) else {
            return
        }

        // Test/manual seam: set Active without Input Source request.
        // Real Activity-Triggered Switching uses handlePhysicalKeyboardEvent.
        activePhysicalKeyboardID = physicalKeyboardID
        publishPhysicalKeyboards()
        onChange?()
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
              connected.id.isIdentityBased
        else {
            return
        }

        guard let disconnected = physicalKeyboards.first(where: { $0.id == disconnectedID }),
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

        if activePhysicalKeyboardID == disconnectedID {
            activePhysicalKeyboardID = connectedID
        }

        publishPhysicalKeyboards()
        onChange?()
    }

    func forgetConfirmationMessage(for physicalKeyboardID: PhysicalKeyboardRecordID) -> String {
        guard let physicalKeyboard = physicalKeyboards.first(where: { $0.id == physicalKeyboardID })
        else {
            return ""
        }

        let removedData =
            "This removes the saved Physical Keyboard Name, Keyboard Assignment, Manual Physical Keyboard Designation, and linked Diagnostic Data for \(physicalKeyboard.name)."
        let reconnectResult =
            switch physicalKeyboard.connectionState {
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
        clearWarning(cause: .unavailableKeyboardAssignment(physicalKeyboardID))

        if activePhysicalKeyboardID == physicalKeyboardID {
            activePhysicalKeyboardID = nil
        }

        if wantedKeyboardAssignment?.physicalKeyboardID == physicalKeyboardID {
            wantedKeyboardAssignment = nil
            wantedKeyboardAssignmentIdentifier = nil
            clearWarning(cause: .selectionFailure)
        }

        publishPhysicalKeyboards()
        onChange?()
    }

    func canStartManualDesignation(for physicalKeyboardID: PhysicalKeyboardRecordID) -> Bool {
        guard manualDesignationPhase == .idle else {
            return false
        }

        guard let physicalKeyboard = physicalKeyboards.first(where: { $0.id == physicalKeyboardID }),
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
        onChange?()
    }

    func cancelManualDesignation() {
        guard manualDesignationPhase != .idle else {
            return
        }

        manualDesignationPhase = .idle
        onChange?()
    }

    func confirmManualDesignationName(_ name: String) {
        guard case let .awaitingNameConfirmation(recordID, productName) = manualDesignationPhase
        else {
            return
        }

        guard ManualPhysicalKeyboardDesignationEvidenceRules.acceptsConfirmedName(name) else {
            return
        }

        // Re-validate same identity group evidence before save.
        guard
            ManualPhysicalKeyboardDesignationEvidenceRules.acceptsReturn(
                connected: physicalKeyboardCatalog.physicalKeyboards,
                expectedID: recordID
            ) != nil
        else {
            manualDesignationPhase = .idle
            publishPhysicalKeyboards()
            onChange?()
            return
        }

        let confirmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let integrityKey = integrityKeyProvider.integrityKey()
        let tag = ManualPhysicalKeyboardDesignationAuthenticator.authenticationTag(
            identityKey: recordID.rawValue,
            productName: productName,
            confirmedName: confirmedName,
            integrityKey: integrityKey
        )
        let designation = SavedManualPhysicalKeyboardDesignation(
            identityKey: recordID.rawValue,
            productName: productName,
            confirmedName: confirmedName,
            authenticationTag: tag
        )
        designationStore.save(designation)
        // Designation alone: name only. No Keyboard Assignment and no Key Content.
        physicalKeyboardRecordStore.saveName(
            identityKey: recordID.rawValue,
            productName: productName,
            customName: confirmedName
        )
        manualDesignationPhase = .idle
        publishPhysicalKeyboards()
        onChange?()
    }

    func manualDesignationStatusText() -> String? {
        switch manualDesignationPhase {
        case .idle:
            nil
        case .awaitingRemoval:
            KeyameleonAppMetadata.manualDesignationAwaitingRemovalMessage
        case .awaitingReturn:
            KeyameleonAppMetadata.manualDesignationAwaitingReturnMessage
        case .awaitingNameConfirmation:
            KeyameleonAppMetadata.manualDesignationAwaitingNameMessage
        }
    }

    func assignmentDisplayName(for physicalKeyboard: PhysicalKeyboard) -> String? {
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

    private func displayName(forInputSourceIdentifier identifier: String) -> String {
        eligibleInputSources.first { $0.identifier == identifier }?.name ?? identifier
    }

    private func refreshInputSources() {
        let refreshedInputSources = inputSourceProvider.eligibleInputSources()
        let sourcesChanged = refreshedInputSources != eligibleInputSources
        if sourcesChanged {
            eligibleInputSources = refreshedInputSources
        }

        let warningsChanged = reevaluateUnavailableKeyboardAssignments()
        if sourcesChanged || warningsChanged {
            onChange?()
        }
    }

    /// Request + verify exact wanted Input Source for one generation.
    /// Leaves normal input unchanged on failure. No timed retry loop.
    @discardableResult
    private func applyWantedKeyboardAssignment(
        _ inputSourceIdentifier: String,
        generation: UInt64
    ) -> Bool {
        inputSourceSelectionRequestCount += 1
        let verified = inputSourceSelector.selectAndVerifyInputSource(
            identifier: inputSourceIdentifier
        )

        // Only the current wanted generation may accept its readback.
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
        observedCurrentInputSourceIdentifier =
            inputSourceSelector.currentInputSourceIdentifier()
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
            eligibleInputSources: eligibleInputSources
        )
    }

    /// Opens or refreshes one warning for an active cause. Counts a new episode only once per cause.
    private func openWarning(_ warning: SwitchingWarning) {
        let isNewEpisode = activeWarningByCause[warning.cause] == nil
        activeWarningByCause[warning.cause] = warning
        if isNewEpisode {
            warningEpisodeCount += 1
        }
        publishActiveWarnings()
    }

    private func clearWarning(cause: SwitchingWarning.Cause) {
        guard activeWarningByCause.removeValue(forKey: cause) != nil else {
            return
        }

        publishActiveWarnings()
    }

    private func publishActiveWarnings() {
        activeWarnings = activeWarningByCause.values.sorted { left, right in
            left.id < right.id
        }
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

    @discardableResult
    private func updateUnavailableReason(
        _ reason: SwitchingUnavailableReason,
        isActive: Bool
    ) -> Bool {
        var reasons = Set(temporarilyUnavailableReasons)
        if isActive {
            reasons.insert(reason)
        } else {
            reasons.remove(reason)
        }

        let orderedReasons = Self.unavailableReasonPriority.filter { reasons.contains($0) }
        guard orderedReasons != temporarilyUnavailableReasons else {
            return false
        }

        temporarilyUnavailableReasons = orderedReasons
        onChange?()
        return true
    }

    private func reconcileProtectedState() {
        let protectedState = protectedStateProvider.currentProtectedState()
        var reasons = Set(temporarilyUnavailableReasons)

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

        let orderedReasons = Self.unavailableReasonPriority.filter { reasons.contains($0) }
        guard orderedReasons != temporarilyUnavailableReasons else {
            return
        }

        temporarilyUnavailableReasons = orderedReasons
        onChange?()
    }

    /// Exact saved Input Source identifier return ends unavailable; substitute names never clear it.
    @discardableResult
    private func reevaluateUnavailableKeyboardAssignments() -> Bool {
        var changed = false
        let eligibleIdentifiers = Set(eligibleInputSources.map(\.identifier))
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
                remainingUnavailableIDs.remove(physicalKeyboardID)
            } else {
                let before = activeWarningByCause[.unavailableKeyboardAssignment(physicalKeyboardID)]
                openWarning(
                    .unavailableKeyboardAssignment(
                        physicalKeyboardID: physicalKeyboardID,
                        inputSourceIdentifier: assignment.inputSourceIdentifier
                    )
                )
                if before == nil
                    || before?.inputSourceIdentifier != assignment.inputSourceIdentifier
                {
                    changed = true
                }
                remainingUnavailableIDs.remove(physicalKeyboardID)
            }
        }

        for staleID in remainingUnavailableIDs {
            clearWarning(cause: .unavailableKeyboardAssignment(staleID))
            changed = true
        }

        return changed
    }

    private func applySwitchingStatus(listenPermission: ListenPermissionState) {
        let newStatus = SwitchingStatus.resolve(
            listenPermission: listenPermission,
            isTemporarilyUnavailable: !temporarilyUnavailableReasons.isEmpty,
            isPaused: isActivityTriggeredSwitchingPaused
        )
        if switchingStatus != newStatus {
            switchingStatus = newStatus
            diagnosticDataController.record(
                code: .switchingStatusChanged,
                identityKey: nil,
                switchingStatus: newStatus
            )
            if newStatus == .permissionRequired {
                diagnosticDataController.record(
                    code: .permissionDenied,
                    identityKey: nil,
                    switchingStatus: newStatus
                )
            }
            onChange?()
        }
    }

    private func refreshObservedCurrentInputSource(publish: Bool) {
        let currentIdentifier = inputSourceSelector.currentInputSourceIdentifier()
        guard currentIdentifier != observedCurrentInputSourceIdentifier else {
            return
        }

        observedCurrentInputSourceIdentifier = currentIdentifier
        if publish {
            onChange?()
        }
    }

    private func updatePhysicalKeyboardDiscovery() {
        guard canDiscoverPhysicalKeyboards else {
            guard isDiscoveryStarted else {
                publishPhysicalKeyboards()
                return
            }

            physicalKeyboardDiscoverer.stop()
            isDiscoveryStarted = false
            physicalKeyboardCatalog = PhysicalKeyboardCatalog()
            publishPhysicalKeyboards()
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
        publishPhysicalKeyboards()
    }

    private func updatePhysicalKeyboardEventObservation() {
        guard canObservePhysicalKeyboards else {
            guard isEventObservationStarted else {
                return
            }

            physicalKeyboardEventObserver.stop()
            isEventObservationStarted = false
            return
        }

        guard !isEventObservationStarted else {
            return
        }

        isEventObservationStarted = true
        physicalKeyboardEventObserver.start { [weak self] event in
            self?.handlePhysicalKeyboardEvent(event)
        }
    }

    private func updateInputSourceChangeObservation() {
        guard switchingStatus.allowsActivityTriggeredSwitching else {
            guard isInputSourceChangeObservationStarted else {
                return
            }

            inputSourceChangeObserver.stop()
            isInputSourceChangeObservationStarted = false
            return
        }

        guard !isInputSourceChangeObservationStarted else {
            return
        }

        isInputSourceChangeObservationStarted = true
        inputSourceChangeObserver.start { [weak self] in
            self?.handleExternalInputSourceChange()
        }
    }

    private func apply(_ change: PhysicalKeyboardDiscoveryChange) {
        guard canDiscoverPhysicalKeyboards else {
            return
        }

        switch change {
        case let .connected(facts):
            physicalKeyboardCatalog.apply(change)
            if let keyboard = physicalKeyboardCatalog.physicalKeyboard(forServiceID: facts.serviceID),
               keyboard.id.isIdentityBased
            {
                diagnosticDataController.record(
                    code: .physicalKeyboardConnected,
                    identityKey: keyboard.id.rawValue,
                    switchingStatus: nil
                )
            }
        case .disconnected:
            let previous = physicalKeyboardCatalog.physicalKeyboards
            physicalKeyboardCatalog.apply(change)
            let remainingIDs = Set(physicalKeyboardCatalog.physicalKeyboards.map(\.id))
            for keyboard in previous where keyboard.id.isIdentityBased && !remainingIDs.contains(keyboard.id) {
                diagnosticDataController.record(
                    code: .physicalKeyboardDisconnected,
                    identityKey: keyboard.id.rawValue,
                    switchingStatus: nil
                )
            }
        }
        // Disconnect never rewrites Active Physical Keyboard and never requests Input Sources.
        advanceManualDesignationSession()
        publishPhysicalKeyboards()
        onChange?()
    }

    private func advanceManualDesignationSession() {
        switch manualDesignationPhase {
        case .idle, .awaitingNameConfirmation:
            return
        case let .awaitingRemoval(recordID):
            let stillConnected = physicalKeyboardCatalog.physicalKeyboards.contains {
                $0.id == recordID
            }
            if !stillConnected {
                manualDesignationPhase = .awaitingReturn(recordID)
            }
        case let .awaitingReturn(recordID):
            let connected = physicalKeyboardCatalog.physicalKeyboards
            if let returned = ManualPhysicalKeyboardDesignationEvidenceRules.acceptsReturn(
                connected: connected,
                expectedID: recordID
            ) {
                manualDesignationPhase = .awaitingNameConfirmation(
                    recordID,
                    productName: returned.productName
                )
                return
            }

            // Invalid, incomplete, shared, or other rejected evidence aborts with no save.
            if connected.contains(where: { $0.id == recordID }) {
                manualDesignationPhase = .idle
            }
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

    private func publishPhysicalKeyboards() {
        let connected = physicalKeyboardCatalog.physicalKeyboards.map { keyboard in
            let published = resolvePublishedPhysicalKeyboard(keyboard)
                .markingActive(keyboard.id == activePhysicalKeyboardID)
            if keyboard.id.isIdentityBased {
                lastKnownPhysicalKeyboards[keyboard.id.rawValue] = published.markingActive(false)
            }
            return published
        }

        let connectedIdentityKeys = Set(
            connected
                .filter(\.id.isIdentityBased)
                .map(\.id.rawValue)
        )

        var disconnected = physicalKeyboardRecordStore
            .allRecords()
            .filter { !connectedIdentityKeys.contains($0.identityKey) }
            .map { savedRecord in
                PhysicalKeyboard
                    .disconnected(from: savedRecord)
                    .markingActive(savedRecord.recordID == activePhysicalKeyboardID)
            }

        let disconnectedIdentityKeys = Set(disconnected.map(\.id.rawValue))

        // Active stays visible as disconnected even when no saved name/assignment yet.
        if let activePhysicalKeyboardID,
           activePhysicalKeyboardID.isIdentityBased,
           !connectedIdentityKeys.contains(activePhysicalKeyboardID.rawValue),
           !disconnectedIdentityKeys.contains(activePhysicalKeyboardID.rawValue),
           let lastKnown = lastKnownPhysicalKeyboards[activePhysicalKeyboardID.rawValue]
        {
            disconnected.append(lastKnown.asDisconnected().markingActive(true))
        }

        physicalKeyboards = PhysicalKeyboardListOrdering.sorted(
            connected + disconnected,
            activeID: activePhysicalKeyboardID
        )
    }

    private func resolvePublishedPhysicalKeyboard(
        _ keyboard: PhysicalKeyboard
    ) -> PhysicalKeyboard {
        guard keyboard.id.isIdentityBased else {
            return keyboard
        }

        let savedRecord = physicalKeyboardRecordStore.record(
            forIdentityKey: keyboard.id.rawValue
        )

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
