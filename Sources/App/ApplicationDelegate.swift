import AppKit
import Darwin
import Observation
@preconcurrency import SwiftData

enum HostedUnitTestProcess {
    static func isDetected(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
    }
}

enum PreviewProcess {
    static func isDetected(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    let setupModel: SetupModel
    let activityTriggeredSwitching: ActivityTriggeredSwitching
    private let updateChecker: any UpdateChecking
    private let lifecycleObserver: any LifecycleObserving
    private let systemSettingsOpener: any SystemSettingsOpening
    private let singleInstanceLock: SingleInstanceLock?
    private let startsUpdaterOnLaunch: Bool
    private let startsApplicationSurfaceOnLaunch: Bool
    let generalSettingsModel: GeneralSettingsModel
    let settingsSelection = SettingsSelection()
    var statusItem: NSStatusItem?
    /// Template status image loaded from `menu_icon.pdf` once per process.
    var menuBarStatusImage: NSImage?
    /// System-symbol fallbacks for a missing PDF, keyed by symbol name.
    var menuBarFallbackImages: [String: NSImage] = [:]
    var menuBarPanelController: MenuBarPanelController?
    var windowController: MainWindowController?
    var settingsWindowController: SettingsWindowController?
    private let modelContainer: ModelContainer?

    override convenience init() {
        let isHostedUnitTest = HostedUnitTestProcess.isDetected()
        let isPreview = PreviewProcess.isDetected()

        let singleInstanceLock: SingleInstanceLock?
        if isPreview {
            singleInstanceLock = nil
        } else {
            guard let acquiredLock = SingleInstanceLock.acquire() else {
                if !isHostedUnitTest {
                    Log.start(.appendOnlyFile())
                    Log.warning(
                        .app,
                        "Another Keyameleon instance is running; exiting"
                    )
                }
                Darwin.exit(SingleInstanceLock.blockedLaunchExitCode)
            }
            singleInstanceLock = acquiredLock
        }

        if !isHostedUnitTest, !isPreview {
            Log.start(.file())
        }
        Log.debug(.app, "Launching Keyameleon \(AppIdentity.current.versionLabel)")

        let persistenceSession = SwiftDataPersistenceSession {
            try SwiftDataPhysicalKeyboardRecordStore.makeContainer(
                inMemory: isHostedUnitTest || isPreview
            )
        }
        let composition = ProductionFactory.makeLiveComposition(
            setupStore: UserDefaultsSetupDecisionStore(),
            physicalKeyboardRecordStore: SwiftDataPhysicalKeyboardRecordStore(session: persistenceSession),
            designationStore: SwiftDataManualPhysicalKeyboardDesignationStore(session: persistenceSession),
            exclusionStore: UserDefaultsPhysicalKeyboardExclusionStore(),
            integrityKeyProvider: KeychainInstallationIntegrityKeyProvider()
        )
        self.init(
            composition: composition,
            systemSettingsOpener: NSWorkspaceSystemSettingsOpener(permissionProvider: composition.permissionProvider),
            lifecycleObserver: SystemLifecycleObserver(),
            launchAtLoginController: ServiceManagementLaunchAtLoginController(),
            updateChecker: SparkleUpdateChecker(),
            startsUpdaterOnLaunch: !isHostedUnitTest,
            startsApplicationSurfaceOnLaunch: !isHostedUnitTest,
            modelContainer: nil,
            singleInstanceLock: singleInstanceLock
        )
    }

    private init(
        composition: ActivityTriggeredSwitchingComposition,
        systemSettingsOpener: any SystemSettingsOpening,
        lifecycleObserver: any LifecycleObserving,
        launchAtLoginController: any LaunchAtLoginControlling,
        updateChecker: any UpdateChecking,
        startsUpdaterOnLaunch: Bool,
        startsApplicationSurfaceOnLaunch: Bool,
        modelContainer: ModelContainer?,
        singleInstanceLock: SingleInstanceLock?
    ) {
        self.modelContainer = modelContainer
        self.singleInstanceLock = singleInstanceLock
        self.updateChecker = updateChecker
        self.lifecycleObserver = lifecycleObserver
        self.systemSettingsOpener = systemSettingsOpener
        self.startsUpdaterOnLaunch = startsUpdaterOnLaunch
        self.startsApplicationSurfaceOnLaunch = startsApplicationSurfaceOnLaunch
        self.activityTriggeredSwitching = composition.activityTriggeredSwitching
        setupModel = SetupModel(
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
        generalSettingsModel = GeneralSettingsModel(
            launchAtLoginController: launchAtLoginController,
            updateChecker: updateChecker
        )

        super.init()
        if let opener = systemSettingsOpener as? NSWorkspaceSystemSettingsOpener {
            opener.onPermissionGranted = { [weak setupModel] in
                setupModel?.activityTriggeredSwitching.checkAgain()
                setupModel?.advanceIfPermissionGranted()
            }
        }
        setupModel.onGuidedSetupCompleted = { [weak self] destination in
            self?.finishGuidedSetup(destination: destination)
        }
        observePresentationChanges()
    }

    convenience init(
        permissionProvider: any ListenPermissionProviding = SystemListenPermissionProvider(),
        protectedStateProvider: any ProtectedStateProviding = SystemProtectedStateProvider(),
        setupStore: any SetupDecisionStoring = UserDefaultsSetupDecisionStore(),
        systemSettingsOpener: (any SystemSettingsOpening)? = nil,
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
        lifecycleObserver: any LifecycleObserving = NoOpLifecycleObserver(),
        launchAtLoginController: any LaunchAtLoginControlling = ServiceManagementLaunchAtLoginController(),
        updateChecker: any UpdateChecking = SparkleUpdateChecker(),
        startsUpdaterOnLaunch: Bool = true,
        startsApplicationSurfaceOnLaunch: Bool = true,
        modelContainer: ModelContainer? = nil,
        singleInstanceLock: SingleInstanceLock?
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
            integrityKeyProvider: integrityKeyProvider
        )
        self.init(
            composition: composition,
            systemSettingsOpener: systemSettingsOpener
                ?? NSWorkspaceSystemSettingsOpener(permissionProvider: composition.permissionProvider),
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
        Log.debug(.app, "Terminating")
        lifecycleObserver.stop()
        systemSettingsOpener.stop()
        activityTriggeredSwitching.stop()
        closeMenuBarPanel()
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
        menuBarPanelController = nil
        settingsWindowController?.close()
        settingsWindowController = nil
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
