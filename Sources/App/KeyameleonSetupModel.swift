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

    private let permissionProvider: any ListenPermissionProviding
    private let setupStore: any SetupDecisionStoring
    private let systemSettingsOpener: any SystemSettingsOpening
    private let physicalKeyboardDiscoverer: any PhysicalKeyboardDiscovering
    private let inputSourceProvider: any InputSourceProviding
    private let inputSourceSelector: any InputSourceSelecting
    private let physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring
    private let physicalKeyboardEventObserver: any PhysicalKeyboardEventObserving
    private var physicalKeyboardCatalog = PhysicalKeyboardCatalog()
    private var isDiscoveryStarted = false
    private var isEventObservationStarted = false

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

        var didVerify = false

        switch physicalKeyboard.assignmentState {
        case let .assigned(assignment):
            // Coalesce when this exact Keyboard Assignment is already verified.
            if verifiedKeyboardAssignmentIdentifier == assignment.inputSourceIdentifier,
               inputSourceSelector.currentInputSourceIdentifier() == assignment.inputSourceIdentifier
            {
                break
            }

            if inputSourceSelector.selectAndVerifyInputSource(
                identifier: assignment.inputSourceIdentifier
            ) {
                verifiedKeyboardAssignmentIdentifier = assignment.inputSourceIdentifier
                didVerify = true
            } else if verifiedKeyboardAssignmentIdentifier == assignment.inputSourceIdentifier {
                // Wanted assignment no longer verified after this Activation Activity.
                verifiedKeyboardAssignmentIdentifier = nil
            }
            // Selection failure restores prior Input Source when possible. No toast. No retry.
        case .unassigned, .unsupported:
            // No Input Source request for unassigned or unsupported Physical Keyboards.
            break
        }

        if activeChanged || didVerify {
            publishPhysicalKeyboards()
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
        publishPhysicalKeyboards()
        onChange?()
    }

    private func publishPhysicalKeyboards() {
        let resolved = physicalKeyboardCatalog.physicalKeyboards.map { keyboard -> PhysicalKeyboard in
            guard keyboard.id.isIdentityBased else {
                return keyboard
            }

            return keyboard.applying(
                savedRecord: physicalKeyboardRecordStore.record(
                    forIdentityKey: keyboard.id.rawValue
                )
            )
        }

        // Active first, then name, then identity. Connected-only catalog for V1 discovery.
        physicalKeyboards = resolved.sorted { left, right in
            let leftActive = left.id == activePhysicalKeyboardID
            let rightActive = right.id == activePhysicalKeyboardID
            if leftActive != rightActive {
                return leftActive
            }

            let nameComparison = left.name.localizedCaseInsensitiveCompare(right.name)
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }

            return left.id.rawValue < right.id.rawValue
        }
    }
}
