import AppKit
import Darwin
import Observation
@preconcurrency import SwiftData

@MainActor
final class KeyameleonApplicationDelegate: NSObject, NSApplicationDelegate {
    let setupModel: KeyameleonSetupModel
    let activityTriggeredSwitching: ActivityTriggeredSwitching
    private let updateChecker: any UpdateChecking
    private let lifecycleObserver: any KeyameleonLifecycleObserving
    private let singleInstanceLock: KeyameleonSingleInstanceLock
    private let startsUpdaterOnLaunch: Bool
    let uncleanExitStateStore: any UncleanExitStateStoring
    let generalSettingsModel: KeyameleonGeneralSettingsModel
    var statusItem: NSStatusItem?
    var menuBarPanelController: KeyameleonMenuBarPanelController?
    var windowController: KeyameleonWindowController?
    var diagnosticReviewWindowController: KeyameleonDiagnosticWindowController?
    private let modelContainer: ModelContainer?
    private let diagnosticModelContainer: ModelContainer?

    override convenience init() {
        guard let singleInstanceLock = KeyameleonSingleInstanceLock.acquire() else {
            Darwin.exit(KeyameleonSingleInstanceLock.blockedLaunchExitCode)
        }

        let setupStore = UserDefaultsSetupDecisionStore()
        let uncleanExitStateStore = UserDefaultsUncleanExitStateStore()
        if ProcessInfo.processInfo.arguments.contains("--reset-guided-setup") {
            setupStore.resetForUITesting()
            uncleanExitStateStore.resetForUITesting()
        }

        let modelContainer: ModelContainer
        do {
            modelContainer = try SwiftDataPhysicalKeyboardRecordStore.makeContainer()
        } catch {
            fatalError("SwiftData container failed for Physical Keyboard records: \(error)")
        }

        let modelContext = ModelContext(modelContainer)

        let diagnosticModelContainer: ModelContainer
        do {
            diagnosticModelContainer = try SwiftDataDiagnosticDataStore.makeContainer()
        } catch {
            fatalError("SwiftData container failed for Diagnostic Data: \(error)")
        }
        let diagnosticDataController = KeyameleonDiagnosticDataService(
            store: SwiftDataDiagnosticDataStore(
                modelContext: ModelContext(diagnosticModelContainer)
            )
        )

        let isUITesting = ProcessInfo.processInfo.arguments.contains("--reset-guided-setup")
        let isXCTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let operationalNotificationProvider: any OperationalNotificationProviding =
            isUITesting || isXCTestHost
                ? NoOpOperationalNotificationProvider()
                : SystemOperationalNotificationProvider()
        let notificationEpisodeStore = UserDefaultsOperationalNotificationEpisodeStore()
        let notificationSetupStore = UserDefaultsNotificationSetupDecisionStore()
        if isUITesting {
            notificationEpisodeStore.resetForUITesting()
            notificationSetupStore.resetForUITesting()
        }
        let physicalKeyboardRecordStore = SwiftDataPhysicalKeyboardRecordStore(
            modelContext: modelContext
        )
        let designationStore = SwiftDataManualPhysicalKeyboardDesignationStore(
            modelContext: modelContext
        )
        let composition = KeyameleonProductionFactory.makeLiveComposition(
            setupStore: setupStore,
            physicalKeyboardRecordStore: physicalKeyboardRecordStore,
            designationStore: designationStore,
            integrityKeyProvider: KeychainInstallationIntegrityKeyProvider(),
            diagnosticDataController: diagnosticDataController,
            operationalNotificationProvider: operationalNotificationProvider,
            notificationEpisodeStore: notificationEpisodeStore,
            notificationSetupStore: notificationSetupStore
        )
        self.init(
            composition: composition,
            systemSettingsOpener: NSWorkspaceSystemSettingsOpener(),
            notificationSettingsOpener: NSWorkspaceNotificationSettingsOpener(),
            uncleanExitStateStore: uncleanExitStateStore,
            lifecycleObserver: SystemKeyameleonLifecycleObserver(),
            launchAtLoginController: ServiceManagementLaunchAtLoginController(),
            updateChecker: SparkleUpdateChecker(),
            // UI tests must not open Sparkle sheets that steal focus from lifecycle checks.
            startsUpdaterOnLaunch: !isUITesting,
            modelContainer: modelContainer,
            diagnosticModelContainer: diagnosticModelContainer,
            singleInstanceLock: singleInstanceLock
        )
    }

    private init(
        composition: KeyameleonActivityTriggeredSwitchingComposition,
        systemSettingsOpener: any SystemSettingsOpening,
        notificationSettingsOpener: any NotificationSettingsOpening,
        uncleanExitStateStore: any UncleanExitStateStoring,
        lifecycleObserver: any KeyameleonLifecycleObserving,
        launchAtLoginController: any LaunchAtLoginControlling,
        updateChecker: any UpdateChecking,
        startsUpdaterOnLaunch: Bool,
        modelContainer: ModelContainer?,
        diagnosticModelContainer: ModelContainer?,
        singleInstanceLock: KeyameleonSingleInstanceLock
    ) {
        self.modelContainer = modelContainer
        self.diagnosticModelContainer = diagnosticModelContainer
        self.singleInstanceLock = singleInstanceLock
        self.updateChecker = updateChecker
        self.lifecycleObserver = lifecycleObserver
        self.startsUpdaterOnLaunch = startsUpdaterOnLaunch
        self.uncleanExitStateStore = uncleanExitStateStore
        self.activityTriggeredSwitching = composition.activityTriggeredSwitching
        setupModel = KeyameleonSetupModel(
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
        generalSettingsModel = KeyameleonGeneralSettingsModel(
            launchAtLoginController: launchAtLoginController,
            updateChecker: updateChecker,
            diagnosticDataController: composition.diagnosticDataController,
            operationalNotifications: composition.operationalNotifications,
            notificationSettingsOpener: notificationSettingsOpener
        )

        super.init()
        observePresentationChanges()
    }

    /// Dependency-injection seam for AppKit tests. A lock is required so this
    /// initializer cannot construct a delegate without single-instance ownership.
    convenience init(
        permissionProvider: any ListenPermissionProviding = SystemListenPermissionProvider(),
        protectedStateProvider: any ProtectedStateProviding = SystemProtectedStateProvider(),
        setupStore: any SetupDecisionStoring = UserDefaultsSetupDecisionStore(),
        systemSettingsOpener: any SystemSettingsOpening = NSWorkspaceSystemSettingsOpener(),
        physicalKeyboardDiscoverer: any PhysicalKeyboardDiscovering =
            SystemPhysicalKeyboardDiscoverer(),
        physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring = InMemoryPhysicalKeyboardRecordStore(),
        designationStore: any ManualPhysicalKeyboardDesignationStoring =
            InMemoryManualPhysicalKeyboardDesignationStore(),
        integrityKeyProvider: any InstallationIntegrityKeyProviding =
            InMemoryInstallationIntegrityKeyProvider(),
        inputSourceProvider: any InputSourceProviding = SystemInputSourceProvider(),
        inputSourceSelector: any InputSourceSelecting = SystemInputSourceProvider(),
        physicalKeyboardEventObserver: any PhysicalKeyboardEventObserving = SystemPhysicalKeyboardEventObserver(),
        inputSourceChangeObserver: any InputSourceChangeObserving = SystemInputSourceChangeObserver(),
        lifecycleObserver: any KeyameleonLifecycleObserving = SystemKeyameleonLifecycleObserver(),
        diagnosticDataController: any DiagnosticDataControlling = KeyameleonDiagnosticDataService(
            store: InMemoryDiagnosticDataStore()
        ),
        operationalNotificationProvider: any OperationalNotificationProviding =
            NoOpOperationalNotificationProvider(),
        notificationEpisodeStore: any OperationalNotificationEpisodeStoring =
            InMemoryOperationalNotificationEpisodeStore(),
        notificationSetupStore: any NotificationSetupDecisionStoring =
            InMemoryNotificationSetupDecisionStore(),
        notificationSettingsOpener: any NotificationSettingsOpening =
            NoOpNotificationSettingsOpener(),
        uncleanExitStateStore: any UncleanExitStateStoring = UserDefaultsUncleanExitStateStore(),
        launchAtLoginController: any LaunchAtLoginControlling = ServiceManagementLaunchAtLoginController(),
        updateChecker: any UpdateChecking = SparkleUpdateChecker(),
        startsUpdaterOnLaunch: Bool = true,
        modelContainer: ModelContainer? = nil,
        diagnosticModelContainer: ModelContainer? = nil,
        singleInstanceLock: KeyameleonSingleInstanceLock
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
            composition: composition,
            systemSettingsOpener: systemSettingsOpener,
            notificationSettingsOpener: notificationSettingsOpener,
            uncleanExitStateStore: uncleanExitStateStore,
            lifecycleObserver: lifecycleObserver,
            launchAtLoginController: launchAtLoginController,
            updateChecker: updateChecker,
            startsUpdaterOnLaunch: startsUpdaterOnLaunch,
            modelContainer: modelContainer,
            diagnosticModelContainer: diagnosticModelContainer,
            singleInstanceLock: singleInstanceLock
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        uncleanExitStateStore.beginLaunch()
        lifecycleObserver.start { [weak self] event in
            self?.activityTriggeredSwitching.handleLifecycleEvent(event)
        }
        activityTriggeredSwitching.start()
        statusItem = makeStatusItem()
        menuBarPanelController = makeMenuBarPanelController()
        refreshMenuBarPresentation()
        if startsUpdaterOnLaunch {
            updateChecker.start()
        }
        generalSettingsModel.refresh()

        if !setupModel.isSetupComplete && !setupModel.hasStartedGuidedSetup {
            setupModel.beginGuidedSetup()
            openKeyameleon(nil)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        activityTriggeredSwitching.checkAgain()
        generalSettingsModel.refresh()
        refreshMenuBarPresentation()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        uncleanExitStateStore.markCleanTermination()
        lifecycleObserver.stop()
        activityTriggeredSwitching.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
