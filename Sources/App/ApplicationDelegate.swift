import AppKit
import Darwin
import Observation
@preconcurrency import SwiftData

enum KeyameleonHostedUnitTestProcess {
    static func isDetected(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
    }
}

enum KeyameleonPreviewProcess {
    static func isDetected(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

@MainActor
final class KeyameleonApplicationDelegate: NSObject, NSApplicationDelegate {
    let setupModel: KeyameleonSetupModel
    let activityTriggeredSwitching: ActivityTriggeredSwitching
    private let updateChecker: any UpdateChecking
    private let lifecycleObserver: any KeyameleonLifecycleObserving
    private let singleInstanceLock: KeyameleonSingleInstanceLock?
    private let startsUpdaterOnLaunch: Bool
    private let startsApplicationSurfaceOnLaunch: Bool
    let generalSettingsModel: KeyameleonGeneralSettingsModel
    let settingsSelection = KeyameleonSettingsSelection()
    var statusItem: NSStatusItem?
    /// Template status image loaded from `menu_icon.pdf` once per process.
    var menuBarStatusImage: NSImage?
    /// System-symbol fallbacks for a missing PDF, keyed by symbol name.
    var menuBarFallbackImages: [String: NSImage] = [:]
    var menuBarPanelController: KeyameleonMenuBarPanelController?
    var windowController: KeyameleonWindowController?
    var settingsWindowController: KeyameleonSettingsWindowController?
    var aboutWindowController: KeyameleonAboutWindowController?
    private let modelContainer: ModelContainer?

    override convenience init() {
        let isHostedUnitTest = KeyameleonHostedUnitTestProcess.isDetected()
        let isPreview = KeyameleonPreviewProcess.isDetected()

        let singleInstanceLock: KeyameleonSingleInstanceLock?
        if isPreview {
            singleInstanceLock = nil
        } else {
            guard let acquiredLock = KeyameleonSingleInstanceLock.acquire() else {
                if !isHostedUnitTest {
                    KeyameleonLog.start(.appendOnlyFile())
                    KeyameleonLog.warning(
                        .app,
                        "Another Keyameleon instance is running; exiting"
                    )
                }
                Darwin.exit(KeyameleonSingleInstanceLock.blockedLaunchExitCode)
            }
            singleInstanceLock = acquiredLock
        }

        if !isHostedUnitTest, !isPreview {
            KeyameleonLog.start(.file())
        }
        KeyameleonLog.debug(
            .app,
            "Launching Keyameleon \(KeyameleonAppIdentity.current.versionLabel)"
        )

        let setupStore = UserDefaultsSetupDecisionStore()

        let modelContainer: ModelContainer
        do {
            modelContainer = try SwiftDataPhysicalKeyboardRecordStore.makeContainer()
        } catch {
            KeyameleonLog.error(.app, "Physical Keyboard records could not be opened")
            fatalError("SwiftData container failed for Physical Keyboard records: \(error)")
        }

        let modelContext = ModelContext(modelContainer)

        let operationalNotificationProvider: any OperationalNotificationProviding =
            isHostedUnitTest
                ? NoOpOperationalNotificationProvider()
                : SystemOperationalNotificationProvider()
        let notificationEpisodeStore = UserDefaultsOperationalNotificationEpisodeStore()
        let notificationSetupStore = UserDefaultsNotificationSetupDecisionStore()
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
            operationalNotificationProvider: operationalNotificationProvider,
            notificationEpisodeStore: notificationEpisodeStore,
            notificationSetupStore: notificationSetupStore
        )
        self.init(
            composition: composition,
            systemSettingsOpener: NSWorkspaceSystemSettingsOpener(),
            notificationSettingsOpener: NSWorkspaceNotificationSettingsOpener(),
            lifecycleObserver: SystemKeyameleonLifecycleObserver(),
            launchAtLoginController: ServiceManagementLaunchAtLoginController(),
            updateChecker: SparkleUpdateChecker(),
            startsUpdaterOnLaunch: !isHostedUnitTest,
            startsApplicationSurfaceOnLaunch: !isHostedUnitTest,
            modelContainer: modelContainer,
            singleInstanceLock: singleInstanceLock
        )
    }

    private init(
        composition: KeyameleonActivityTriggeredSwitchingComposition,
        systemSettingsOpener: any SystemSettingsOpening,
        notificationSettingsOpener: any NotificationSettingsOpening,
        lifecycleObserver: any KeyameleonLifecycleObserving,
        launchAtLoginController: any LaunchAtLoginControlling,
        updateChecker: any UpdateChecking,
        startsUpdaterOnLaunch: Bool,
        startsApplicationSurfaceOnLaunch: Bool,
        modelContainer: ModelContainer?,
        singleInstanceLock: KeyameleonSingleInstanceLock?
    ) {
        self.modelContainer = modelContainer
        self.singleInstanceLock = singleInstanceLock
        self.updateChecker = updateChecker
        self.lifecycleObserver = lifecycleObserver
        self.startsUpdaterOnLaunch = startsUpdaterOnLaunch
        self.startsApplicationSurfaceOnLaunch = startsApplicationSurfaceOnLaunch
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
            operationalNotifications: composition.operationalNotifications
        )
        generalSettingsModel = KeyameleonGeneralSettingsModel(
            launchAtLoginController: launchAtLoginController,
            updateChecker: updateChecker,
            operationalNotifications: composition.operationalNotifications,
            notificationSettingsOpener: notificationSettingsOpener
        )

        super.init()
        setupModel.onGuidedSetupCompleted = { [weak self] in
            self?.presentSettingsAfterGuidedSetup()
        }
        observePresentationChanges()
    }

    convenience init(
        permissionProvider: any ListenPermissionProviding = SystemListenPermissionProvider(),
        protectedStateProvider: any ProtectedStateProviding = SystemProtectedStateProvider(),
        setupStore: any SetupDecisionStoring = UserDefaultsSetupDecisionStore(),
        systemSettingsOpener: any SystemSettingsOpening = NSWorkspaceSystemSettingsOpener(),
        physicalKeyboardDiscoverer: any PhysicalKeyboardDiscovering =
            NoOpPhysicalKeyboardDiscoverer(),
        physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring = InMemoryPhysicalKeyboardRecordStore(),
        designationStore: any ManualPhysicalKeyboardDesignationStoring =
            InMemoryManualPhysicalKeyboardDesignationStore(),
        integrityKeyProvider: any InstallationIntegrityKeyProviding =
            InMemoryInstallationIntegrityKeyProvider(),
        inputSourceProvider: any InputSourceProviding = NoOpInputSourceProvider(),
        inputSourceSelector: any InputSourceSelecting = NoOpInputSourceSelector(),
        physicalKeyboardEventObserver: any PhysicalKeyboardEventObserving =
            NoOpPhysicalKeyboardEventObserver(),
        inputSourceChangeObserver: any InputSourceChangeObserving = NoOpInputSourceChangeObserver(),
        lifecycleObserver: any KeyameleonLifecycleObserving = NoOpKeyameleonLifecycleObserver(),
        operationalNotificationProvider: any OperationalNotificationProviding =
            NoOpOperationalNotificationProvider(),
        notificationEpisodeStore: any OperationalNotificationEpisodeStoring =
            InMemoryOperationalNotificationEpisodeStore(),
        notificationSetupStore: any NotificationSetupDecisionStoring =
            InMemoryNotificationSetupDecisionStore(),
        notificationSettingsOpener: any NotificationSettingsOpening =
            NoOpNotificationSettingsOpener(),
        launchAtLoginController: any LaunchAtLoginControlling = ServiceManagementLaunchAtLoginController(),
        updateChecker: any UpdateChecking = SparkleUpdateChecker(),
        startsUpdaterOnLaunch: Bool = true,
        startsApplicationSurfaceOnLaunch: Bool = true,
        modelContainer: ModelContainer? = nil,
        singleInstanceLock: KeyameleonSingleInstanceLock?
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
            operationalNotificationProvider: operationalNotificationProvider,
            notificationEpisodeStore: notificationEpisodeStore,
            notificationSetupStore: notificationSetupStore
        )
        self.init(
            composition: composition,
            systemSettingsOpener: systemSettingsOpener,
            notificationSettingsOpener: notificationSettingsOpener,
            lifecycleObserver: lifecycleObserver,
            launchAtLoginController: launchAtLoginController,
            updateChecker: updateChecker,
            startsUpdaterOnLaunch: startsUpdaterOnLaunch,
            startsApplicationSurfaceOnLaunch: startsApplicationSurfaceOnLaunch,
            modelContainer: modelContainer,
            singleInstanceLock: singleInstanceLock
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if startsApplicationSurfaceOnLaunch {
            lifecycleObserver.start { [weak self] event in
                self?.activityTriggeredSwitching.handleLifecycleEvent(event)
            }
            activityTriggeredSwitching.start()
            statusItem = makeStatusItem()
            menuBarPanelController = makeMenuBarPanelController()
            refreshMenuBarPresentation()
        }
        if startsUpdaterOnLaunch {
            updateChecker.start()
        }
        generalSettingsModel.refresh()

        if startsApplicationSurfaceOnLaunch, !setupModel.isSetupComplete {
            setupModel.beginGuidedSetup()
            openKeyameleon(nil)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        activityTriggeredSwitching.checkAgain()
        setupModel.advanceIfPermissionGranted()
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
        KeyameleonLog.debug(.app, "Terminating")
        lifecycleObserver.stop()
        activityTriggeredSwitching.stop()
        closeMenuBarPanel()
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
        menuBarPanelController = nil
        settingsWindowController?.close()
        settingsWindowController = nil
        aboutWindowController?.close()
        aboutWindowController = nil
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
