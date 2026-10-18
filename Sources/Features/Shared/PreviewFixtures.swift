#if DEBUG
import AppKit
import CryptoKit
import Foundation

@MainActor
enum PreviewFixtures {
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
        canCheckForUpdates: Bool = true,
        externalChangeResponse: ExternalChangeResponse = .switchBack
    ) -> GeneralSettingsModel {
        let model = GeneralSettingsModel(
            launchAtLoginController: PreviewLaunchAtLoginController(
                isEnabled: launchAtLoginEnabled,
                shouldFail: launchAtLoginFailure
            ),
            updateChecker: PreviewUpdateChecker(canCheck: canCheckForUpdates),
            activityTriggeredSwitching: setup(.completed).model.activityTriggeredSwitching
        )
        model.setExternalChangeResponse(externalChangeResponse)

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
        let requiresPermission = state == .permissionRequired || state == .permissionDenied
        let isCompleted = state == .completed || (menuCompleted && requiresPermission)
        let isPaused = menuPaused || state == .paused || state == .readyPaused
        let step = guidedStep(for: state)
        let setupStore = PreviewSetupDecisionStore(
            hasStartedGuidedSetup: !isCompleted,
            hasCompletedGuidedSetup: isCompleted,
            guidedSetupStep: step,
            isPaused: isPaused
        )
        let permission: ListenPermissionState = switch state {
        case .permissionRequired: .unknown
        case .permissionDenied: .denied
        default: .granted
        }
        let permissionProvider = PreviewListenPermissionProvider(state: permission)
        let discoverer = PreviewPhysicalKeyboardDiscoverer()
        let inMemoryRecordStore = InMemoryPhysicalKeyboardRecordStore()
        seedDisconnectedRecord(into: inMemoryRecordStore, state: state)
        let (recordStore, designationStore) = persistenceStores(for: state, seededRecords: inMemoryRecordStore)

        let model = SetupModel(
            permissionProvider: permissionProvider,
            protectedStateProvider: PreviewProtectedStateProvider(),
            setupStore: setupStore,
            inputMonitoringRecovery: PreviewInputMonitoringRecovery(),
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

        guard !requiresPermission, state != .assignmentsEmpty, state != .readyEmpty,
              state != .persistenceFailure, !isCompleted else {
            return PreviewSetupFixture(model: model, switching: switching)
        }

        for fact in hardwareFacts(for: state) {
            discoverer.emit(.connected(fact))
        }
        configureAssignments(for: model, state: state)

        excludePencilTravelIfNeeded(from: model, discoverer: discoverer, state: state)

        if state == .excludedDevices,
           let pointer = model.physicalKeyboards.first(where: { !$0.isAssignable }) {
            model.excludePhysicalKeyboard(pointer.id)
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
        case .permissionRequired, .permissionDenied: .permission
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

    /// Terminal assigned to U.S., Notes running without an assignment, and an
    /// assigned app that is not installed.
    static func appAssignments() -> AppAssignmentsModel {
        let terminal = InstalledApp(
            bundleIdentifier: "com.apple.Terminal",
            name: "Terminal",
            url: URL(filePath: "/System/Applications/Utilities/Terminal.app")
        )
        let notes = InstalledApp(
            bundleIdentifier: "com.apple.Notes",
            name: "Notes",
            url: URL(filePath: "/System/Applications/Notes.app")
        )
        return AppAssignmentsModel(
            store: InMemoryAppAssignmentStore([
                AppAssignment(
                    bundleIdentifier: terminal.bundleIdentifier,
                    appName: terminal.name,
                    inputSourceIdentifier: "com.apple.keylayout.US"
                ),
                AppAssignment(
                    bundleIdentifier: "com.example.Removed",
                    appName: "Removed App",
                    inputSourceIdentifier: "com.apple.keylayout.German"
                )
            ]),
            apps: InMemoryInstalledApps(
                installed: [terminal, notes],
                running: [terminal.bundleIdentifier, notes.bundleIdentifier]
            )
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
}

#endif
