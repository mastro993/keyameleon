#if DEBUG
import AppKit
import CryptoKit
import Foundation

enum PreviewSetupState: Equatable {
    case permissionRequired
    case permissionWaiting
    case assignmentsEmpty
    case assignmentsPopulated
    case pencilAssignments
    case menuAssignments
    case readyEmpty
    case readyPopulated
    case readyPaused
    case persistenceFailure
    case mixedAssignments
    case manyAssignments
    case excludedDevices
    case designationInProgress
    case paused
    case completed
}

@MainActor
struct PreviewSetupFixture {
    let model: SetupModel
    let switching: ActivityTriggeredSwitching
}

@MainActor
enum PreviewFixtures {
    static let fixedDate = Date(timeIntervalSince1970: 1_735_689_600)

    static func setupWithAllKeyboardsExcluded() -> PreviewSetupFixture {
        let fixture = setup(.excludedDevices)
        fixture.model.physicalKeyboards.forEach { physicalKeyboard in
            fixture.model.excludePhysicalKeyboard(physicalKeyboard.id)
        }
        return fixture
    }

    static let aboutInfo = AboutInfo(
        identity: AppIdentity(
            infoDictionary: [
                "CFBundleDisplayName": "Keyameleon",
                "CFBundleShortVersionString": "9.9.9",
                "CFBundleVersion": "1"
            ]
        ),
        repositoryURL: URL(string: "https://github.com/mastro993/Keyameleon")!,
        appDataFolderURL: URL(fileURLWithPath: "/tmp/Keyameleon/PreviewData", isDirectory: true),
        logsFolderURL: URL(fileURLWithPath: "/tmp/Keyameleon/PreviewLogs", isDirectory: true)
    )

    static func general(
        launchAtLoginEnabled: Bool = false,
        launchAtLoginFailure: Bool = false,
        canCheckForUpdates: Bool = true
    ) -> GeneralSettingsModel {
        let model = GeneralSettingsModel(
            launchAtLoginController: PreviewLaunchAtLoginController(
                isEnabled: launchAtLoginEnabled,
                shouldFail: launchAtLoginFailure
            ),
            updateChecker: PreviewUpdateChecker(canCheck: canCheckForUpdates)
        )

        if launchAtLoginFailure {
            model.setLaunchAtLoginEnabled(!launchAtLoginEnabled)
        }
        return model
    }

    static func setup(
        _ state: PreviewSetupState,
        menuCompleted: Bool = false,
        menuPaused: Bool = false
    ) -> PreviewSetupFixture {
        let requiresPermission = state == .permissionRequired || state == .permissionWaiting
        let isCompleted = state == .completed || (menuCompleted && requiresPermission)
        let isPaused = menuPaused || state == .paused || state == .readyPaused
        let step = guidedStep(for: state)
        let setupStore = PreviewSetupDecisionStore(
            hasStartedGuidedSetup: !isCompleted,
            hasCompletedGuidedSetup: isCompleted,
            guidedSetupStep: step,
            isPaused: isPaused
        )
        let permissionProvider = PreviewListenPermissionProvider(
            state: requiresPermission ? .denied : .granted,
            grantsOnRequest: state != .permissionWaiting
        )
        let discoverer = PreviewPhysicalKeyboardDiscoverer()
        let inMemoryRecordStore = InMemoryPhysicalKeyboardRecordStore()
        seedDisconnectedRecord(into: inMemoryRecordStore, state: state)
        let (recordStore, designationStore) = persistenceStores(for: state, seededRecords: inMemoryRecordStore)

        let model = SetupModel(
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
            designationStore: designationStore,
            integrityKeyProvider: InMemoryInstallationIntegrityKeyProvider(
                key: SymmetricKey(data: Data(repeating: 42, count: 32))
            )
        )
        defer {
            finishMenuFixture(model, discoverer: discoverer, state: state, completed: menuCompleted)
        }
        let switching = model.activityTriggeredSwitching
        switching.start()
        if state == .permissionWaiting {
            model.requestPermission()
        }

        guard !requiresPermission, state != .assignmentsEmpty, state != .readyEmpty,
              state != .persistenceFailure, !isCompleted else {
            return PreviewSetupFixture(model: model, switching: switching)
        }

        let facts = hardwareFacts(for: state)
        for fact in facts {
            discoverer.emit(.connected(fact))
        }
        configureAssignments(for: model, state: state)

        excludePencilTravelIfNeeded(from: model, discoverer: discoverer, state: state)

        if state == .excludedDevices,
           let pointer = model.physicalKeyboards.first(where: { !$0.isAssignable }) {
            model.excludePhysicalKeyboard(pointer.id)
        }

        if state == .designationInProgress,
           let keyboard = model.physicalKeyboards.first(where: {
               if case .unsupported(.ambiguousIdentity) = $0.assignmentState {
                   return true
               }
               return false
           }) {
            model.startManualDesignation(for: keyboard.id)
            for serviceID: UInt64 in [40, 41] {
                discoverer.emit(.disconnected(serviceID: serviceID))
            }
            for fact in facts where fact.serviceID == 40 {
                discoverer.emit(.connected(fact))
            }
        }

        if [.assignmentsPopulated, .readyPopulated, .readyPaused, .mixedAssignments, .paused].contains(state) {
            if let active = model.physicalKeyboards.first {
                switching.markActiveForTesting(active.id)
            }
        }

        return PreviewSetupFixture(model: model, switching: switching)
    }

    private static func finishMenuFixture(
        _ model: SetupModel,
        discoverer: PreviewPhysicalKeyboardDiscoverer,
        state: PreviewSetupState,
        completed: Bool
    ) {
        if state == .menuAssignments {
            discoverer.emit(.disconnected(serviceID: 11))
            if let office = model.physicalKeyboards.first(where: { $0.productName == "Keychron K2" }) {
                model.activityTriggeredSwitching.markActiveForTesting(office.id)
            }
        }
        if completed {
            model.continueToReady()
            model.completeSetup(destination: .menuBar)
        }
    }

    private static func excludePencilTravelIfNeeded(
        from model: SetupModel,
        discoverer: PreviewPhysicalKeyboardDiscoverer,
        state: PreviewSetupState
    ) {
        guard state == .pencilAssignments,
              let travel = model.physicalKeyboards.first(where: { $0.productName == "HHKB Professional" })
        else {
            return
        }
        model.excludePhysicalKeyboard(travel.id)
        discoverer.emit(.disconnected(serviceID: 11))
    }

    private static func persistenceStores(
        for state: PreviewSetupState,
        seededRecords: InMemoryPhysicalKeyboardRecordStore
    ) -> (any PhysicalKeyboardRecordStoring, any ManualPhysicalKeyboardDesignationStoring) {
        guard state == .persistenceFailure else {
            return (seededRecords, InMemoryManualPhysicalKeyboardDesignationStore())
        }
        let session = SwiftDataPersistenceSession(openContainer: { throw CocoaError(.fileReadNoPermission) })
        return (
            SwiftDataPhysicalKeyboardRecordStore(session: session),
            SwiftDataManualPhysicalKeyboardDesignationStore(session: session)
        )
    }

    private static func guidedStep(for state: PreviewSetupState) -> GuidedSetupStep {
        switch state {
        case .permissionRequired, .permissionWaiting: .permission
        case .readyEmpty, .readyPopulated, .readyPaused: .ready
        default: .assignments
        }
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
            EligibleInputSource(
                identifier: "com.apple.keylayout.Italian",
                name: "Italian",
                localeCode: "IT"
            ),
            EligibleInputSource(
                identifier: "com.apple.keylayout.US",
                name: "U.S.",
                localeCode: "US"
            ),
            EligibleInputSource(
                identifier: "com.apple.keylayout.German",
                name: "German",
                localeCode: "DE"
            )
        ]
    }

    private static func seedDisconnectedRecord(
        into store: InMemoryPhysicalKeyboardRecordStore,
        state: PreviewSetupState
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
        for state: PreviewSetupState
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
        case .assignmentsPopulated, .readyPopulated, .readyPaused, .paused:
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
        case .pencilAssignments, .menuAssignments:
            let facts = [
                PhysicalKeyboardHardwareFacts(
                    serviceID: 8,
                    identity: PhysicalKeyboardIdentity(
                        rawValue: "preview.macbook", isBuiltIn: true, serialNumber: nil
                    ),
                    name: "MacBook Keyboard",
                    transport: .usb,
                    isBuiltIn: true,
                    vendorID: 500,
                    productID: 100,
                    modelNumber: "MacBook",
                    serialNumber: nil
                ),
                makeFacts(
                    serviceID: 10, identity: "preview.travel", serial: "travel", name: "Keychron K2"
                ),
                makeFacts(
                    serviceID: 11, identity: "preview.desk", serial: "desk", name: "HHKB Professional"
                ),
                makeFacts(
                    serviceID: 12, identity: "preview.magic", serial: "magic", name: "Magic Keyboard"
                )
            ]
            return state == .menuAssignments ? facts.filter { $0.serviceID != 12 } : facts
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
        case .excludedDevices:
            return [
                makeFacts(
                    serviceID: 30,
                    identity: "preview.travel",
                    serial: "travel",
                    name: "Keychron K2"
                ),
                makeFacts(
                    serviceID: 31,
                    identity: nil,
                    serial: nil,
                    name: "Logitech USB Receiver",
                    vendorID: 200
                )
            ]
        case .permissionRequired, .permissionWaiting, .assignmentsEmpty, .readyEmpty, .persistenceFailure, .completed:
            return []
        }
    }

    private static func configureAssignments(
        for model: SetupModel,
        state: PreviewSetupState
    ) {
        for keyboard in model.physicalKeyboards where keyboard.isAssignable {
            switch keyboard.productName {
            case "Keychron K2":
                model.setPhysicalKeyboardName(
                    keyboard.id,
                    customName: [.pencilAssignments, .menuAssignments].contains(state) ? "Office Keyboard" : "Travel"
                )
                model.setKeyboardAssignment(
                    keyboard.id,
                    inputSourceIdentifier: [.pencilAssignments, .menuAssignments].contains(state)
                        ? "com.apple.keylayout.US" : "com.apple.keylayout.Italian"
                )
            case "HHKB Professional":
                if [.pencilAssignments, .menuAssignments].contains(state) {
                    model.setPhysicalKeyboardName(keyboard.id, customName: "Travel Keyboard")
                }
                if [.assignmentsPopulated, .paused, .pencilAssignments, .menuAssignments].contains(state) {
                    model.setKeyboardAssignment(
                        keyboard.id,
                        inputSourceIdentifier: [.pencilAssignments, .menuAssignments].contains(state)
                            ? "com.apple.keylayout.German" : "com.apple.keylayout.US"
                    )
                }
            case "MacBook Keyboard":
                model.setKeyboardAssignment(
                    keyboard.id, inputSourceIdentifier: "com.apple.keylayout.Italian"
                )
            case "Magic Keyboard":
                model.setKeyboardAssignment(
                    keyboard.id, inputSourceIdentifier: "com.apple.keylayout.US"
                )
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
           let desk = model.physicalKeyboards.first(where: { $0.productName == "HHKB Professional" }) {
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
final class PreviewListenPermissionProvider: ListenPermissionProviding {
    private(set) var state: ListenPermissionState
    private let grantsOnRequest: Bool

    init(state: ListenPermissionState, grantsOnRequest: Bool = true) {
        self.state = state
        self.grantsOnRequest = grantsOnRequest
    }

    func checkListenPermission() -> ListenPermissionState {
        state
    }

    func requestListenPermission() -> Bool {
        if grantsOnRequest {
            state = .granted
        }
        return grantsOnRequest
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
        guidedSetupStep = .ready
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
        PreviewFixtures.inputSources()
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
