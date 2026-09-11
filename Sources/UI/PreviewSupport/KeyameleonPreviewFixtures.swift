#if DEBUG
import AppKit
import CryptoKit
import Foundation

enum KeyameleonPreviewSetupState: Equatable {
    case permissionRequired
    case assignmentsEmpty
    case assignmentsPopulated
    case mixedAssignments
    case manyAssignments
    case designationInProgress
    case paused
    case completed
}

@MainActor
struct KeyameleonPreviewSetupFixture {
    let model: KeyameleonSetupModel
    let switching: ActivityTriggeredSwitching
}

@MainActor
enum KeyameleonPreviewFixtures {
    static let fixedDate = Date(timeIntervalSince1970: 1_735_689_600)

    static let aboutInfo = KeyameleonAboutInfo(
        identity: KeyameleonAppIdentity(
            infoDictionary: [
                "CFBundleDisplayName": "Keyameleon",
                "CFBundleShortVersionString": "9.9.9"
            ]
        ),
        repositoryURL: URL(string: "https://github.com/mastro993/Keyameleon")!,
        appDataFolderURL: URL(fileURLWithPath: "/tmp/Keyameleon/PreviewData", isDirectory: true),
        logsFolderURL: URL(fileURLWithPath: "/tmp/Keyameleon/PreviewLogs", isDirectory: true)
    )

    static func general(
        launchAtLoginEnabled: Bool = false,
        launchAtLoginFailure: Bool = false,
        canCheckForUpdates: Bool = true,
        notificationState: OperationalNotificationAuthorizationState = .authorized,
        diagnosticRecords: [DiagnosticRecord] = [],
        diagnosticSessionActive: Bool = false
    ) -> KeyameleonGeneralSettingsModel {
        let diagnosticStore = InMemoryDiagnosticDataStore()
        for record in diagnosticRecords {
            diagnosticStore.insert(record)
        }
        let diagnostic = KeyameleonDiagnosticDataService(
            store: diagnosticStore,
            clock: ManualClock(now: fixedDate)
        )
        if diagnosticSessionActive {
            diagnostic.startDiagnosticSession()
        }

        let model = KeyameleonGeneralSettingsModel(
            launchAtLoginController: PreviewLaunchAtLoginController(
                isEnabled: launchAtLoginEnabled,
                shouldFail: launchAtLoginFailure
            ),
            updateChecker: PreviewUpdateChecker(canCheck: canCheckForUpdates),
            diagnosticDataController: diagnostic,
            operationalNotificationProvider: PreviewOperationalNotificationProvider(
                authorizationState: notificationState
            ),
            notificationSettingsOpener: PreviewNotificationSettingsOpener()
        )

        if launchAtLoginFailure {
            model.setLaunchAtLoginEnabled(!launchAtLoginEnabled)
        }
        return model
    }

    static func generalWithDiagnosticData() -> KeyameleonGeneralSettingsModel {
        general(
            diagnosticRecords: [
                DiagnosticRecord(
                    id: UUID(uuidString: "B6CDB3D6-0F31-4C1D-9C6F-0D8F0D5C0A01")!,
                    recordedAt: fixedDate.addingTimeInterval(-120),
                    code: .discoveryFailed,
                    switchingStatus: .temporarilyUnavailable,
                    insertionOrder: 1
                ),
                DiagnosticRecord(
                    id: UUID(uuidString: "B6CDB3D6-0F31-4C1D-9C6F-0D8F0D5C0A02")!,
                    recordedAt: fixedDate.addingTimeInterval(-60),
                    code: .switchingStatusChanged,
                    switchingStatus: .ready,
                    insertionOrder: 2
                )
            ]
        )
    }

    static func setup(
        _ state: KeyameleonPreviewSetupState
    ) -> KeyameleonPreviewSetupFixture {
        let requiresPermission = state == .permissionRequired
        let isCompleted = state == .completed
        let isPaused = state == .paused
        let step: GuidedSetupStep = requiresPermission ? .permission : .assignments
        let setupStore = PreviewSetupDecisionStore(
            hasStartedGuidedSetup: !isCompleted,
            hasCompletedGuidedSetup: isCompleted,
            guidedSetupStep: step,
            isPaused: isPaused
        )
        let permissionProvider = PreviewListenPermissionProvider(
            state: requiresPermission ? .denied : .granted
        )
        let discoverer = PreviewPhysicalKeyboardDiscoverer()
        let recordStore = InMemoryPhysicalKeyboardRecordStore()
        seedDisconnectedRecord(into: recordStore, state: state)

        let model = KeyameleonSetupModel(
            permissionProvider: permissionProvider,
            protectedStateProvider: PreviewProtectedStateProvider(),
            setupStore: setupStore,
            systemSettingsOpener: PreviewSystemSettingsOpener(),
            physicalKeyboardDiscoverer: discoverer,
            inputSourceProvider: PreviewInputSourceProvider(),
            inputSourceSelector: PreviewInputSourceSelector(current: "com.apple.keylayout.US"),
            physicalKeyboardRecordStore: recordStore,
            physicalKeyboardEventObserver: NoOpPhysicalKeyboardEventObserver(),
            inputSourceChangeObserver: NoOpInputSourceChangeObserver(),
            designationStore: InMemoryManualPhysicalKeyboardDesignationStore(),
            integrityKeyProvider: InMemoryInstallationIntegrityKeyProvider(
                key: SymmetricKey(data: Data(repeating: 42, count: 32))
            ),
            diagnosticDataController: KeyameleonDiagnosticDataService(
                store: InMemoryDiagnosticDataStore(),
                clock: ManualClock(now: fixedDate)
            ),
            operationalNotificationProvider: PreviewOperationalNotificationProvider(
                authorizationState: .authorized
            )
        )
        let switching = model.activityTriggeredSwitching
        switching.start()

        guard !requiresPermission, state != .assignmentsEmpty, !isCompleted else {
            return KeyameleonPreviewSetupFixture(model: model, switching: switching)
        }

        let facts = hardwareFacts(for: state)
        for fact in facts {
            discoverer.emit(.connected(fact))
        }
        configureAssignments(for: model, state: state)

        if state == .designationInProgress,
           let keyboard = model.physicalKeyboards.first(where: {
               if case .unsupported(.ambiguousIdentity) = $0.assignmentState {
                   return true
               }
               return false
           })
        {
            model.startManualDesignation(for: keyboard.id)
            for serviceID: UInt64 in [40, 41] {
                discoverer.emit(.disconnected(serviceID: serviceID))
            }
            for fact in facts where fact.serviceID == 40 {
                discoverer.emit(.connected(fact))
            }
        }

        if state == .assignmentsPopulated || state == .mixedAssignments || state == .paused {
            if let active = model.physicalKeyboards.first {
                switching.markActiveForTesting(active.id)
            }
        }

        return KeyameleonPreviewSetupFixture(model: model, switching: switching)
    }

    static func panelActions() -> MenuBarPanelActions {
        MenuBarPanelActions(
            openAbout: {},
            openSettings: {},
            quit: {},
            closePanel: {}
        )
    }

    static func aboutAction() -> MenuBarPanelContent.Action {
        MenuBarPanelContent.Action(
            id: .about,
            title: "About Keyameleon",
            isEnabled: true,
            closesPanel: true
        )
    }

    static func panelActionList(
        paused: Bool = false
    ) -> [MenuBarPanelContent.Action] {
        [
            MenuBarPanelContent.Action(
                id: paused ? .resume : .pause,
                title: paused ? "Resume" : "Pause",
                isEnabled: true,
                closesPanel: false
            ),
            MenuBarPanelContent.Action(
                id: .settings,
                title: "Settings",
                isEnabled: true,
                closesPanel: true
            ),
            MenuBarPanelContent.Action(
                id: .quit,
                title: "Quit Keyameleon",
                isEnabled: true,
                closesPanel: true
            )
        ]
    }

    static func physicalKeyboard(
        name: String = "Keychron K2",
        id: String = "identity:preview.keyboard|anchor:serial:preview-keyboard",
        assignment: String? = "com.apple.keylayout.Italian",
        connection: PhysicalKeyboardConnectionState = .connected,
        isActive: Bool = false
    ) -> PhysicalKeyboard {
        PhysicalKeyboard(
            id: PhysicalKeyboardRecordID(rawValue: id),
            productName: name,
            customName: nil,
            transport: .usb,
            isBuiltIn: false,
            assignmentState: assignment.flatMap(KeyboardAssignment.init(inputSourceIdentifier:))
                .map(PhysicalKeyboardAssignmentState.assigned)
                ?? .unassigned,
            connectedServiceCount: connection == .connected ? 1 : 0,
            connectionState: connection,
            isActive: isActive
        )
    }

    static func unsupportedPhysicalKeyboard(
        name: String = "Unidentifiable Keyboard",
        reason: PhysicalKeyboardUnsupportedReason = .missingIdentity,
        connection: PhysicalKeyboardConnectionState = .connected
    ) -> PhysicalKeyboard {
        PhysicalKeyboard(
            id: PhysicalKeyboardRecordID(rawValue: "service:preview-unsupported"),
            productName: name,
            customName: nil,
            transport: .usb,
            isBuiltIn: false,
            assignmentState: .unsupported(reason),
            connectedServiceCount: connection == .connected ? 1 : 0,
            connectionState: connection,
            isActive: false
        )
    }

    static func inputSources() -> [EligibleInputSource] {
        [
            EligibleInputSource(identifier: "com.apple.keylayout.Italian", name: "Italian"),
            EligibleInputSource(identifier: "com.apple.keylayout.US", name: "U.S."),
            EligibleInputSource(identifier: "com.apple.keylayout.German", name: "German")
        ]
    }

    private static func seedDisconnectedRecord(
        into store: InMemoryPhysicalKeyboardRecordStore,
        state: KeyameleonPreviewSetupState
    ) {
        guard state == .mixedAssignments || state == .designationInProgress else {
            return
        }

        store.saveName(
            identityKey: stableRecordID(identity: "preview.disconnected"),
            productName: "HHKB Professional",
            customName: "Office Keyboard"
        )
        store.saveAssignment(
            identityKey: stableRecordID(identity: "preview.disconnected"),
            productName: "HHKB Professional",
            assignment: KeyboardAssignment(inputSourceIdentifier: "com.apple.keylayout.German")
        )
    }

    private static func hardwareFacts(
        for state: KeyameleonPreviewSetupState
    ) -> [PhysicalKeyboardHardwareFacts] {
        switch state {
        case .designationInProgress:
            return [
                makeFacts(
                    serviceID: 40,
                    identity: "preview.ambiguous",
                    serial: "ambiguous",
                    name: "Prototype Keyboard",
                    vendorID: 100
                ),
                makeFacts(
                    serviceID: 41,
                    identity: "preview.ambiguous",
                    serial: "ambiguous",
                    name: "Prototype Keyboard",
                    vendorID: 101
                )
            ]
        case .assignmentsPopulated, .paused:
            return [
                makeFacts(
                    serviceID: 10,
                    identity: "preview.travel",
                    serial: "travel",
                    name: "Keychron K2"
                ),
                makeFacts(
                    serviceID: 11,
                    identity: "preview.desk",
                    serial: "desk",
                    name: "HHKB Professional"
                )
            ]
        case .manyAssignments:
            return (1...6).map { index in
                makeFacts(
                    serviceID: UInt64(60 + index),
                    identity: "preview.board.\(index)",
                    serial: "board-\(index)",
                    name: "Board \(index)"
                )
            }
        case .mixedAssignments:
            return [
                makeFacts(
                    serviceID: 20,
                    identity: "preview.travel",
                    serial: "travel",
                    name: "Keychron K2"
                ),
                makeFacts(
                    serviceID: 21,
                    identity: "preview.desk",
                    serial: "desk",
                    name: "HHKB Professional"
                ),
                makeFacts(
                    serviceID: 22,
                    identity: nil,
                    serial: nil,
                    name: "Unidentifiable Keyboard"
                )
            ]
        case .permissionRequired, .assignmentsEmpty, .completed:
            return []
        }
    }

    private static func configureAssignments(
        for model: KeyameleonSetupModel,
        state: KeyameleonPreviewSetupState
    ) {
        for keyboard in model.physicalKeyboards where keyboard.isAssignable {
            switch keyboard.productName {
            case "Keychron K2":
                model.setPhysicalKeyboardName(keyboard.id, customName: "Travel")
                model.setKeyboardAssignment(
                    keyboard.id,
                    inputSourceIdentifier: "com.apple.keylayout.Italian"
                )
            case "HHKB Professional":
                if state == .assignmentsPopulated || state == .paused {
                    model.setKeyboardAssignment(
                        keyboard.id,
                        inputSourceIdentifier: "com.apple.keylayout.US"
                    )
                }
            case "Unidentifiable Keyboard":
                break
            case let name where state == .manyAssignments && name.hasPrefix("Board "):
                model.setKeyboardAssignment(
                    keyboard.id,
                    inputSourceIdentifier: "com.apple.keylayout.Italian"
                )
            default:
                break
            }
        }

        if state == .mixedAssignments,
           let desk = model.physicalKeyboards.first(where: { $0.productName == "HHKB Professional" })
        {
            model.setKeyboardAssignment(
                desk.id,
                inputSourceIdentifier: "com.apple.keylayout.Missing"
            )
        }
    }

    private static func makeFacts(
        serviceID: UInt64,
        identity: String?,
        serial: String?,
        name: String,
        vendorID: UInt32 = 42
    ) -> PhysicalKeyboardHardwareFacts {
        PhysicalKeyboardHardwareFacts(
            serviceID: serviceID,
            identity: identity.flatMap {
                PhysicalKeyboardIdentity(
                    rawValue: $0,
                    isBuiltIn: false,
                    serialNumber: serial
                )
            },
            name: name,
            transport: .usb,
            isBuiltIn: false,
            vendorID: vendorID,
            productID: 7,
            modelNumber: "Preview",
            serialNumber: serial
        )
    }

    private static func stableRecordID(identity: String) -> String {
        "identity:\(identity)|anchor:serial:\(identity)"
    }
}

@MainActor
final class PreviewLaunchAtLoginController: LaunchAtLoginControlling {
    private(set) var isEnabled: Bool
    private let shouldFail: Bool

    init(isEnabled: Bool, shouldFail: Bool) {
        self.isEnabled = isEnabled
        self.shouldFail = shouldFail
    }

    func setEnabled(_ enabled: Bool) -> Result<Void, LaunchAtLoginChangeError> {
        guard !shouldFail else {
            return .failure(.registrationFailed)
        }
        isEnabled = enabled
        return .success(())
    }
}

@MainActor
final class PreviewUpdateChecker: UpdateChecking {
    private(set) var canCheckForUpdates: Bool

    init(canCheck: Bool) {
        canCheckForUpdates = canCheck
    }

    func start() {
        canCheckForUpdates = true
    }

    func checkForUpdates() {}
}

@MainActor
final class PreviewOperationalNotificationProvider: OperationalNotificationProviding {
    private(set) var authorizationState: OperationalNotificationAuthorizationState

    init(authorizationState: OperationalNotificationAuthorizationState) {
        self.authorizationState = authorizationState
    }

    func refreshAuthorization(
        onChange: @escaping @MainActor (OperationalNotificationAuthorizationState) -> Void
    ) {
        onChange(authorizationState)
    }

    func requestAlertAuthorization(
        onChange: @escaping @MainActor (OperationalNotificationAuthorizationState) -> Void
    ) {
        authorizationState = .authorized
        onChange(authorizationState)
    }

    func send(_ notification: OperationalNotification) {}
}

@MainActor
final class PreviewNotificationSettingsOpener: NotificationSettingsOpening {
    func openNotificationSettings() {}
}

@MainActor
final class PreviewListenPermissionProvider: ListenPermissionProviding {
    private(set) var state: ListenPermissionState

    init(state: ListenPermissionState) {
        self.state = state
    }

    func checkListenPermission() -> ListenPermissionState {
        state
    }

    func requestListenPermission() -> Bool {
        state = .granted
        return true
    }
}

@MainActor
final class PreviewProtectedStateProvider: ProtectedStateProviding {
    func currentProtectedState() -> ProtectedStateSnapshot {
        .clear
    }
}

@MainActor
final class PreviewSystemSettingsOpener: SystemSettingsOpening {
    func openSystemSettings() {}
}

@MainActor
final class PreviewSetupDecisionStore: SetupDecisionStoring {
    private(set) var hasStartedGuidedSetup: Bool
    private(set) var hasCompletedGuidedSetup: Bool
    private(set) var guidedSetupStep: GuidedSetupStep
    private(set) var isActivityTriggeredSwitchingPaused: Bool
    private(set) var hasEvaluatedBuiltInIdentityMigration = true

    init(
        hasStartedGuidedSetup: Bool,
        hasCompletedGuidedSetup: Bool,
        guidedSetupStep: GuidedSetupStep,
        isPaused: Bool
    ) {
        self.hasStartedGuidedSetup = hasStartedGuidedSetup
        self.hasCompletedGuidedSetup = hasCompletedGuidedSetup
        self.guidedSetupStep = guidedSetupStep
        isActivityTriggeredSwitchingPaused = isPaused
    }

    func markGuidedSetupStarted() {
        hasStartedGuidedSetup = true
    }

    func markGuidedSetupStep(_ step: GuidedSetupStep) {
        hasStartedGuidedSetup = true
        guidedSetupStep = step
    }

    func markGuidedSetupCompleted() {
        hasStartedGuidedSetup = true
        hasCompletedGuidedSetup = true
        guidedSetupStep = .assignments
    }

    func setActivityTriggeredSwitchingPaused(_ paused: Bool) {
        isActivityTriggeredSwitchingPaused = paused
    }

    func markBuiltInIdentityMigrationEvaluated() {
        hasEvaluatedBuiltInIdentityMigration = true
    }
}

@MainActor
final class PreviewPhysicalKeyboardDiscoverer: PhysicalKeyboardDiscovering {
    private var onChange: (@MainActor (PhysicalKeyboardDiscoveryChange) -> Void)?

    func start(onChange: @escaping @MainActor (PhysicalKeyboardDiscoveryChange) -> Void) {
        self.onChange = onChange
    }

    func stop() {
        onChange = nil
    }

    func emit(_ change: PhysicalKeyboardDiscoveryChange) {
        onChange?(change)
    }
}

@MainActor
final class PreviewInputSourceProvider: InputSourceProviding {
    func eligibleInputSources() -> [EligibleInputSource] {
        KeyameleonPreviewFixtures.inputSources()
    }
}

@MainActor
final class PreviewInputSourceSelector: InputSourceSelecting {
    private(set) var current: String?

    init(current: String?) {
        self.current = current
    }

    func currentInputSourceIdentifier() -> String? {
        current
    }

    func selectAndVerifyInputSource(identifier: String) -> Bool {
        current = identifier
        return true
    }
}

#endif
