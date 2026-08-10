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

    func markGuidedSetupStarted()
    func markGuidedSetupStep(_ step: GuidedSetupStep)
    func markGuidedSetupCompleted()
}

@MainActor
final class UserDefaultsSetupDecisionStore: SetupDecisionStoring {
    private enum Key {
        static let hasStartedGuidedSetup = "keyameleon.guidedSetup.started"
        static let hasCompletedGuidedSetup = "keyameleon.guidedSetup.completed"
        static let guidedSetupStep = "keyameleon.guidedSetup.step"
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

    func resetForUITesting() {
        defaults.removeObject(forKey: Key.hasStartedGuidedSetup)
        defaults.removeObject(forKey: Key.hasCompletedGuidedSetup)
        defaults.removeObject(forKey: Key.guidedSetupStep)
    }
}

@MainActor
final class KeyameleonSetupModel: ObservableObject {
    @Published private(set) var switchingStatus: SwitchingStatus
    @Published private(set) var isSetupComplete: Bool
    @Published private(set) var hasStartedGuidedSetup: Bool
    @Published private(set) var guidedSetupStep: GuidedSetupStep
    @Published private(set) var physicalKeyboards: [PhysicalKeyboard] = []
    @Published private(set) var eligibleInputSources: [EligibleInputSource] = []
    /// Not persisted across app restart. Nil until first Activation Activity.
    @Published private(set) var activePhysicalKeyboardID: PhysicalKeyboardRecordID?
    /// Last Keyboard Assignment verified active via exact identifier readback.
    @Published private(set) var verifiedKeyboardAssignmentIdentifier: String?
    @Published private(set) var inputSourceSelectionRequestCount = 0
    /// Number of times a new warning cause became active. Not one per Physical Keyboard Event.
    @Published private(set) var warningEpisodeCount = 0
    /// One warning per active cause. Plain failure category + recovery action only.
    @Published private(set) var activeWarnings: [SwitchingWarning] = []
    /// Latest wanted Keyboard Assignment for Retry Now. Replaced by newer assigned Activation Activity.
    @Published private(set) var wantedKeyboardAssignment: WantedKeyboardAssignment?

    private let permissionProvider: any ListenPermissionProviding
    private let setupStore: any SetupDecisionStoring
    private let systemSettingsOpener: any SystemSettingsOpening
    private let physicalKeyboardDiscoverer: any PhysicalKeyboardDiscovering
    private let inputSourceProvider: any InputSourceProviding
    private let inputSourceSelector: any InputSourceSelecting
    private let physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring
    private let physicalKeyboardEventObserver: any PhysicalKeyboardEventObserving
    private var physicalKeyboardCatalog = PhysicalKeyboardCatalog()
    private var lastKnownPhysicalKeyboards: [String: PhysicalKeyboard] = [:]
    private var isDiscoveryStarted = false
    private var isEventObservationStarted = false
    private var activeWarningByCause: [SwitchingWarning.Cause: SwitchingWarning] = [:]

    var onChange: (@MainActor () -> Void)?

    var canObservePhysicalKeyboards: Bool {
        switchingStatus.allowsActivityTriggeredSwitching
    }

    var canRequestInputSources: Bool {
        switchingStatus.allowsActivityTriggeredSwitching
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

    init(
        permissionProvider: any ListenPermissionProviding,
        setupStore: any SetupDecisionStoring,
        systemSettingsOpener: any SystemSettingsOpening,
        physicalKeyboardDiscoverer: any PhysicalKeyboardDiscovering = SystemPhysicalKeyboardDiscoverer(),
        inputSourceProvider: any InputSourceProviding = SystemInputSourceProvider(),
        inputSourceSelector: any InputSourceSelecting = SystemInputSourceProvider(),
        physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring = InMemoryPhysicalKeyboardRecordStore(),
        physicalKeyboardEventObserver: any PhysicalKeyboardEventObserving = NoOpPhysicalKeyboardEventObserver()
    ) {
        self.permissionProvider = permissionProvider
        self.setupStore = setupStore
        self.systemSettingsOpener = systemSettingsOpener
        self.physicalKeyboardDiscoverer = physicalKeyboardDiscoverer
        self.inputSourceProvider = inputSourceProvider
        self.inputSourceSelector = inputSourceSelector
        self.physicalKeyboardRecordStore = physicalKeyboardRecordStore
        self.physicalKeyboardEventObserver = physicalKeyboardEventObserver
        self.switchingStatus = permissionProvider.checkListenPermission().switchingStatus
        self.isSetupComplete = setupStore.hasCompletedGuidedSetup
        self.hasStartedGuidedSetup = setupStore.hasStartedGuidedSetup
        self.guidedSetupStep = setupStore.guidedSetupStep
    }

    func refreshPermission() {
        let newStatus = permissionProvider.checkListenPermission().switchingStatus
        if switchingStatus != newStatus {
            switchingStatus = newStatus
            onChange?()
        }

        refreshInputSources()
        updatePhysicalKeyboardDiscovery()
        updatePhysicalKeyboardEventObservation()
    }

    /// Serial activity consumer entry. Observation order only.
    func handlePhysicalKeyboardEvent(_ event: PhysicalKeyboardEvent) {
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

        // Resolve saved assignment onto the catalog record.
        let physicalKeyboard = attributed.id.isIdentityBased
            ? attributed.applying(
                savedRecord: physicalKeyboardRecordStore.record(
                    forIdentityKey: attributed.id.rawValue
                )
            )
            : attributed

        let activeChanged = activePhysicalKeyboardID != physicalKeyboard.id
        if activeChanged {
            activePhysicalKeyboardID = physicalKeyboard.id
        }

        var didStateChange = false

        switch physicalKeyboard.assignmentState {
        case let .assigned(assignment):
            // Newer assigned Activation Activity replaces older wanted state.
            wantedKeyboardAssignment = WantedKeyboardAssignment(
                physicalKeyboardID: physicalKeyboard.id,
                inputSourceIdentifier: assignment.inputSourceIdentifier
            )

            if isUnavailable(assignment) {
                // Keep saved assignment. Never select a substitute.
                clearWarning(cause: .selectionFailure)
                openWarning(
                    .unavailableKeyboardAssignment(
                        physicalKeyboardID: physicalKeyboard.id,
                        inputSourceIdentifier: assignment.inputSourceIdentifier
                    )
                )
                if verifiedKeyboardAssignmentIdentifier == assignment.inputSourceIdentifier {
                    verifiedKeyboardAssignmentIdentifier = nil
                }
                didStateChange = true
                break
            }

            // Coalesce when this exact Keyboard Assignment is already verified.
            if verifiedKeyboardAssignmentIdentifier == assignment.inputSourceIdentifier,
               inputSourceSelector.currentInputSourceIdentifier() == assignment.inputSourceIdentifier
            {
                clearWarning(cause: .selectionFailure)
                break
            }

            _ = applyWantedKeyboardAssignment(assignment.inputSourceIdentifier)
            didStateChange = true
        case .unassigned, .unsupported:
            // No Input Source request for unassigned or unsupported Physical Keyboards.
            break
        }

        if activeChanged || didStateChange {
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

        _ = applyWantedKeyboardAssignment(wanted.inputSourceIdentifier)
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

        clearWarning(cause: .unavailableKeyboardAssignment(physicalKeyboardID))

        if wantedKeyboardAssignment?.physicalKeyboardID == physicalKeyboardID {
            // Assignment change invalidates prior selection-failure for this wanted state.
            clearWarning(cause: .selectionFailure)
            if let assignment {
                wantedKeyboardAssignment = WantedKeyboardAssignment(
                    physicalKeyboardID: physicalKeyboardID,
                    inputSourceIdentifier: assignment.inputSourceIdentifier
                )
            } else {
                wantedKeyboardAssignment = nil
            }
        }

        if let assignment {
            if isUnavailable(assignment) {
                openWarning(
                    .unavailableKeyboardAssignment(
                        physicalKeyboardID: physicalKeyboardID,
                        inputSourceIdentifier: assignment.inputSourceIdentifier
                    )
                )
            }
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
            "This removes the saved Physical Keyboard Name and Keyboard Assignment for \(physicalKeyboard.name)."
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
        lastKnownPhysicalKeyboards.removeValue(forKey: physicalKeyboardID.rawValue)
        clearWarning(cause: .unavailableKeyboardAssignment(physicalKeyboardID))

        if activePhysicalKeyboardID == physicalKeyboardID {
            activePhysicalKeyboardID = nil
        }

        if wantedKeyboardAssignment?.physicalKeyboardID == physicalKeyboardID {
            wantedKeyboardAssignment = nil
            clearWarning(cause: .selectionFailure)
        }

        publishPhysicalKeyboards()
        onChange?()
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

    /// Request + verify exact wanted Input Source. Leaves normal input unchanged on failure.
    /// No timed retry loop. Returns true when exact verification succeeds.
    @discardableResult
    private func applyWantedKeyboardAssignment(_ inputSourceIdentifier: String) -> Bool {
        inputSourceSelectionRequestCount += 1
        if inputSourceSelector.selectAndVerifyInputSource(identifier: inputSourceIdentifier) {
            verifiedKeyboardAssignmentIdentifier = inputSourceIdentifier
            clearWarning(cause: .selectionFailure)
            return true
        }

        if verifiedKeyboardAssignmentIdentifier == inputSourceIdentifier {
            verifiedKeyboardAssignmentIdentifier = nil
        }

        openWarning(.selectionFailure(inputSourceIdentifier: inputSourceIdentifier))
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

    private func updatePhysicalKeyboardDiscovery() {
        guard switchingStatus.allowsActivityTriggeredSwitching else {
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
        guard switchingStatus.allowsActivityTriggeredSwitching else {
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

    private func apply(_ change: PhysicalKeyboardDiscoveryChange) {
        guard switchingStatus.allowsActivityTriggeredSwitching else {
            return
        }

        physicalKeyboardCatalog.apply(change)
        // Disconnect never rewrites Active Physical Keyboard and never requests Input Sources.
        publishPhysicalKeyboards()
        onChange?()
    }

    private func publishPhysicalKeyboards() {
        let connected = physicalKeyboardCatalog.physicalKeyboards.map { keyboard in
            guard keyboard.id.isIdentityBased else {
                return keyboard.markingActive(keyboard.id == activePhysicalKeyboardID)
            }

            let published = keyboard
                .applying(
                    savedRecord: physicalKeyboardRecordStore.record(
                        forIdentityKey: keyboard.id.rawValue
                    )
                )
                .markingActive(keyboard.id == activePhysicalKeyboardID)
            lastKnownPhysicalKeyboards[keyboard.id.rawValue] = published.markingActive(false)
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
}
