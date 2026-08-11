import AppKit
import Observation
@preconcurrency import SwiftData

@MainActor
final class KeyameleonApplicationDelegate: NSObject, NSApplicationDelegate {
    private let setupModel: KeyameleonSetupModel
    private let activityTriggeredSwitching: ActivityTriggeredSwitching
    private let updateChecker: any UpdateChecking
    private let lifecycleObserver: any KeyameleonLifecycleObserving
    private let startsUpdaterOnLaunch: Bool
    private let uncleanExitStateStore: any UncleanExitStateStoring
    let generalSettingsModel: KeyameleonGeneralSettingsModel
    private var statusItem: NSStatusItem?
    private var windowController: KeyameleonWindowController?
    private var diagnosticReviewWindowController: KeyameleonDiagnosticWindowController?
    private let modelContainer: ModelContainer?
    private let diagnosticModelContainer: ModelContainer?
    /// Avoid replacing the opening menu while `menuNeedsUpdate` repopulates it.
    private var isPopulatingOpenMenu = false
    private var isStatusMenuOpen = false

    private lazy var menuDelegate = KeyameleonMenuDelegate { [weak self] menu in
        guard let self else {
            return
        }

        // Refresh in place — do not replace the open menu instance.
        self.isPopulatingOpenMenu = true
        self.activityTriggeredSwitching.checkAgain()
        self.populateMenu(menu)
        if let button = self.statusItem?.button {
            self.applyMenuBarIcon(to: button)
        }
        self.isPopulatingOpenMenu = false
    } onVisibilityChange: { [weak self] isOpen in
        self?.isStatusMenuOpen = isOpen
    }

    override convenience init() {
        let setupStore = UserDefaultsSetupDecisionStore()
        let uncleanExitStateStore = UserDefaultsUncleanExitStateStore()
        if ProcessInfo.processInfo.arguments.contains(KeyameleonAppMetadata.uiTestingResetSetupLaunchArgument) {
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

        let isUITesting = ProcessInfo.processInfo.arguments.contains(
            KeyameleonAppMetadata.uiTestingResetSetupLaunchArgument
        )
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
            diagnosticModelContainer: diagnosticModelContainer
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
        diagnosticModelContainer: ModelContainer?
    ) {
        self.modelContainer = modelContainer
        self.diagnosticModelContainer = diagnosticModelContainer
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
        diagnosticModelContainer: ModelContainer? = nil
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
            diagnosticModelContainer: diagnosticModelContainer
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

    func applicationWillTerminate(_ notification: Notification) {
        uncleanExitStateStore.markCleanTermination()
        lifecycleObserver.stop()
        activityTriggeredSwitching.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu(title: KeyameleonAppMetadata.displayName)
        menu.autoenablesItems = false
        populateMenu(menu)
        menu.delegate = menuDelegate
        return menu
    }

    private func populateMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let switchingOutcome = activityTriggeredSwitching.outcome
        let activePhysicalKeyboardValue =
            switchingOutcome.activePhysicalKeyboard?.name
                ?? KeyameleonAppMetadata.noActivityObservedYet
        let activeKeyboardAssignmentValue = keyboardAssignmentMenuValue(
            switchingOutcome.currentKeyboardAssignment
        )
        let currentInputSourceValue =
            switchingOutcome.currentInputSourceName
                ?? KeyameleonAppMetadata.menuValueUnavailable

        let statusItem = NSMenuItem(
            title: KeyameleonAppMetadata.switchingStatusMenuItemTitle(
                switchingOutcome.switchingStatus
            ),
            action: nil,
            keyEquivalent: ""
        )
        statusItem.isEnabled = false
        statusItem.setAccessibilityLabel("Switching Status")
        statusItem.setAccessibilityValue(switchingOutcome.switchingStatus.displayName)
        menu.addItem(statusItem)

        if let reason = switchingOutcome.temporarilyUnavailableReasons.first {
            let reasonItem = NSMenuItem(
                title: KeyameleonAppMetadata.switchingStatusReasonMenuItemTitle(reason),
                action: nil,
                keyEquivalent: ""
            )
            reasonItem.isEnabled = false
            reasonItem.setAccessibilityLabel(KeyameleonAppMetadata.switchingStatusReasonMenuItemPrefix)
            reasonItem.setAccessibilityValue(reason.displayName)
            menu.addItem(reasonItem)

            let recoveryItem = NSMenuItem(
                title: KeyameleonAppMetadata.temporarilyUnavailableAutomaticRecovery,
                action: nil,
                keyEquivalent: ""
            )
            recoveryItem.isEnabled = false
            menu.addItem(recoveryItem)
        }

        addUncleanExitNoticeIfNeeded(to: menu)

        let activeKeyboardItem = NSMenuItem(
            title: KeyameleonAppMetadata.activePhysicalKeyboardMenuItemTitle(
                activePhysicalKeyboardValue
            ),
            action: nil,
            keyEquivalent: ""
        )
        activeKeyboardItem.isEnabled = false
        activeKeyboardItem.setAccessibilityLabel(KeyameleonAppMetadata.activePhysicalKeyboardLabel)
        activeKeyboardItem.setAccessibilityValue(activePhysicalKeyboardValue)
        menu.addItem(activeKeyboardItem)

        let assignmentItem = NSMenuItem(
            title: KeyameleonAppMetadata.keyboardAssignmentMenuItemTitle(
                activeKeyboardAssignmentValue
            ),
            action: nil,
            keyEquivalent: ""
        )
        assignmentItem.isEnabled = false
        assignmentItem.setAccessibilityLabel(KeyameleonAppMetadata.keyboardAssignmentLabel)
        assignmentItem.setAccessibilityValue(activeKeyboardAssignmentValue)
        menu.addItem(assignmentItem)

        let currentInputSourceItem = NSMenuItem(
            title: KeyameleonAppMetadata.currentInputSourceMenuItemTitle(
                currentInputSourceValue
            ),
            action: nil,
            keyEquivalent: ""
        )
        currentInputSourceItem.isEnabled = false
        currentInputSourceItem.setAccessibilityLabel(KeyameleonAppMetadata.currentInputSourceLabel)
        currentInputSourceItem.setAccessibilityValue(currentInputSourceValue)
        menu.addItem(currentInputSourceItem)

        if let mismatch = switchingOutcome.mismatch {
            let assignedItem = NSMenuItem(
                title: "\(KeyameleonAppMetadata.assignedInputSourceLabel): \(mismatch.assignedName)",
                action: nil,
                keyEquivalent: ""
            )
            assignedItem.isEnabled = false
            menu.addItem(assignedItem)

            let restoreItem = NSMenuItem(
                title: KeyameleonAppMetadata.inputSourceRestoresAfterActivation,
                action: nil,
                keyEquivalent: ""
            )
            restoreItem.isEnabled = false
            menu.addItem(restoreItem)
        }

        let actionItems = setupModel.menuFirstActionItems
        if !actionItems.isEmpty {
            menu.addItem(.separator())
            for actionItem in actionItems {
                let item = NSMenuItem(
                    title: actionItem.menuTitle,
                    action: nil,
                    keyEquivalent: ""
                )
                item.isEnabled = false
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        if switchingOutcome.hasAction(.resume) {
            let resumeItem = NSMenuItem(
                title: KeyameleonAppMetadata.resumeActivityTriggeredSwitchingMenuItemTitle,
                action: #selector(resumeActivityTriggeredSwitching(_:)),
                keyEquivalent: ""
            )
            resumeItem.target = self
            menu.addItem(resumeItem)
        } else if switchingOutcome.hasAction(.pause) {
            let pauseItem = NSMenuItem(
                title: KeyameleonAppMetadata.pauseActivityTriggeredSwitchingMenuItemTitle,
                action: #selector(pauseActivityTriggeredSwitching(_:)),
                keyEquivalent: ""
            )
            pauseItem.target = self
            menu.addItem(pauseItem)
        }

        menu.addItem(.separator())

        let openItem = NSMenuItem(
            title: KeyameleonAppMetadata.openMenuItemTitle,
            action: #selector(openKeyameleon(_:)),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        if !setupModel.isSetupComplete {
            let continueSetupItem = NSMenuItem(
                title: KeyameleonAppMetadata.continueSetupMenuItemTitle,
                action: #selector(continueSetup(_:)),
                keyEquivalent: ""
            )
            continueSetupItem.target = self
            menu.addItem(continueSetupItem)
        }

        menu.addItem(.separator())

        if switchingOutcome.hasAction(.openSystemSettings)
            && switchingOutcome.hasAction(.checkAgain)
        {
            let openSystemSettingsItem = NSMenuItem(
                title: KeyameleonAppMetadata.openSystemSettingsMenuItemTitle,
                action: #selector(openSystemSettings(_:)),
                keyEquivalent: ""
            )
            openSystemSettingsItem.target = self
            menu.addItem(openSystemSettingsItem)

            let checkAgainItem = NSMenuItem(
                title: KeyameleonAppMetadata.checkAgainMenuItemTitle,
                action: #selector(checkAgain(_:)),
                keyEquivalent: ""
            )
            checkAgainItem.target = self
            menu.addItem(checkAgainItem)
        }

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: KeyameleonAppMetadata.settingsMenuItemTitle,
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let checkForUpdatesItem = NSMenuItem(
            title: KeyameleonAppMetadata.checkForUpdatesMenuItemTitle,
            action: #selector(checkForUpdates(_:)),
            keyEquivalent: ""
        )
        checkForUpdatesItem.target = self
        checkForUpdatesItem.isEnabled = generalSettingsModel.canCheckForUpdates
        menu.addItem(checkForUpdatesItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: KeyameleonAppMetadata.quitMenuItemTitle,
            action: #selector(quitKeyameleon(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc
    private func openKeyameleon(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)

        if windowController == nil {
            windowController = KeyameleonWindowController(
                model: setupModel,
                switching: activityTriggeredSwitching,
                diagnosticModel: generalSettingsModel
            )
        }

        windowController?.showWindow(sender)
        windowController?.window?.orderFrontRegardless()
    }

    @objc
    private func reviewDiagnostics(_ sender: Any?) {
        uncleanExitStateStore.dismissUncleanExitNotice()
        generalSettingsModel.refresh()
        if diagnosticReviewWindowController == nil {
            diagnosticReviewWindowController = KeyameleonDiagnosticWindowController(
                model: generalSettingsModel
            )
        }

        diagnosticReviewWindowController?.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
        refreshMenuBarPresentation()
    }

    @objc
    private func dismissDiagnosticsNotice(_ sender: Any?) {
        uncleanExitStateStore.dismissUncleanExitNotice()
        refreshMenuBarPresentation()
    }

    @objc
    private func continueSetup(_ sender: Any?) {
        if !setupModel.hasStartedGuidedSetup {
            setupModel.beginGuidedSetup()
        }
        openKeyameleon(sender)
    }

    @objc
    private func openSystemSettings(_ sender: Any?) {
        setupModel.openSystemSettings()
    }

    @objc
    private func checkAgain(_ sender: Any?) {
        activityTriggeredSwitching.checkAgain()
        refreshMenuBarPresentation()
    }

    @objc
    private func pauseActivityTriggeredSwitching(_ sender: Any?) {
        activityTriggeredSwitching.pause()
        refreshMenuBarPresentation()
    }

    @objc
    private func resumeActivityTriggeredSwitching(_ sender: Any?) {
        activityTriggeredSwitching.resume()
        refreshMenuBarPresentation()
    }

    @objc
    private func openSettings(_ sender: Any?) {
        generalSettingsModel.refresh()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    private func checkForUpdates(_ sender: Any?) {
        generalSettingsModel.checkForUpdates()
        refreshMenuBarPresentation()
    }

    @objc
    private func quitKeyameleon(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.terminate(sender)
    }

    private func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = item.button else {
            return item
        }

        button.imagePosition = .imageOnly
        button.setAccessibilityElement(true)
        button.setAccessibilityRole(.button)
        button.setAccessibilityLabel(KeyameleonAppMetadata.menuBarAccessibilityLabel)
        item.menu = makeMenu()
        applyMenuBarIcon(to: button)
        return item
    }

    private func refreshMenuBarPresentation() {
        guard let statusItem else {
            return
        }

        if !isPopulatingOpenMenu,
           !isStatusMenuOpen,
           let menu = statusItem.menu
        {
            // Keep one NSMenu instance. Replacing it while AppKit opens the status menu
            // can invalidate the menu item that accessibility clients are traversing.
            populateMenu(menu)
        }
        if let button = statusItem.button {
            applyMenuBarIcon(to: button)
        }
    }

    private func applyMenuBarIcon(to button: NSStatusBarButton) {
        let outcome = activityTriggeredSwitching.outcome
        let hasItemConditionsNeedingAction = !setupModel.menuFirstActionItems.isEmpty
            || !setupModel.isSetupComplete
            || outcome.mismatch != nil
        let mark = MenuBarIconMark.resolve(
            switchingStatus: outcome.switchingStatus,
            hasItemConditionsNeedingAction: hasItemConditionsNeedingAction
        )
        // Image accessibilityDescription must stay "Keyameleon" — XCUITest matches that id.
        // Distinct SF Symbol shape + tooltip carry status without relying on color alone.
        let image =
            NSImage(
                systemSymbolName: mark.systemSymbolName,
                accessibilityDescription: KeyameleonAppMetadata.displayName
            )
            ?? NSImage(
                systemSymbolName: MenuBarIconMark.ready.systemSymbolName,
                accessibilityDescription: KeyameleonAppMetadata.displayName
            )
        image?.isTemplate = true
        button.image = image
        button.toolTip = mark.accessibilityDescription
        button.setAccessibilityLabel(KeyameleonAppMetadata.menuBarAccessibilityLabel)
    }

    private func keyboardAssignmentMenuValue(
        _ assignment: ActivityTriggeredSwitchingKeyboardAssignment
    ) -> String {
        switch assignment {
        case .none:
            KeyameleonAppMetadata.menuValueUnavailable
        case .unassigned:
            "Unassigned"
        case let .assigned(name):
            name
        case .unavailable:
            "Unavailable Keyboard Assignment"
        case let .unsupported(reason):
            "Unsupported — \(reason.displayName)"
        }
    }

    private func observePresentationChanges() {
        withObservationTracking {
            _ = activityTriggeredSwitching.outcome
            _ = setupModel.physicalKeyboards
            _ = setupModel.isSetupComplete
            _ = setupModel.menuFirstActionItems
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                self.refreshMenuBarPresentation()
                self.observePresentationChanges()
            }
        }
    }

    private func addUncleanExitNoticeIfNeeded(to menu: NSMenu) {
        guard uncleanExitStateStore.hasPendingUncleanExitNotice else {
            return
        }

        menu.addItem(.separator())

        let noticeItem = NSMenuItem(
            title: KeyameleonAppMetadata.uncleanExitNoticeTitle,
            action: nil,
            keyEquivalent: ""
        )
        noticeItem.isEnabled = false
        noticeItem.setAccessibilityLabel(KeyameleonAppMetadata.uncleanExitNoticeTitle)
        noticeItem.setAccessibilityValue(KeyameleonAppMetadata.uncleanExitNoticeMessage)
        menu.addItem(noticeItem)

        let reviewItem = NSMenuItem(
            title: KeyameleonAppMetadata.reviewDiagnosticsMenuItemTitle,
            action: #selector(reviewDiagnostics(_:)),
            keyEquivalent: ""
        )
        reviewItem.target = self
        menu.addItem(reviewItem)

        let dismissItem = NSMenuItem(
            title: KeyameleonAppMetadata.dismissDiagnosticsNoticeMenuItemTitle,
            action: #selector(dismissDiagnosticsNotice(_:)),
            keyEquivalent: ""
        )
        dismissItem.target = self
        menu.addItem(dismissItem)
    }
}

@MainActor
private final class KeyameleonMenuDelegate: NSObject, NSMenuDelegate {
    private let onMenuNeedsUpdate: @MainActor (NSMenu) -> Void
    private let onVisibilityChange: @MainActor (Bool) -> Void

    init(
        onMenuNeedsUpdate: @escaping @MainActor (NSMenu) -> Void,
        onVisibilityChange: @escaping @MainActor (Bool) -> Void
    ) {
        self.onMenuNeedsUpdate = onMenuNeedsUpdate
        self.onVisibilityChange = onVisibilityChange
        super.init()
    }

    func menuWillOpen(_ menu: NSMenu) {
        onVisibilityChange(true)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        // Refresh permission and observed Input Source before Menu first paints.
        onMenuNeedsUpdate(menu)
    }

    func menuDidClose(_ menu: NSMenu) {
        onVisibilityChange(false)
    }
}
