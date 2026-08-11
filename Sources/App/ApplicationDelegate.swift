import AppKit
import Darwin
import Observation
@preconcurrency import SwiftData

@MainActor
final class KeyameleonApplicationDelegate: NSObject, NSApplicationDelegate {
    private let setupModel: KeyameleonSetupModel
    private let activityTriggeredSwitching: ActivityTriggeredSwitching
    private let updateChecker: any UpdateChecking
    private let lifecycleObserver: any KeyameleonLifecycleObserving
    private let singleInstanceLock: KeyameleonSingleInstanceLock
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

    func makeMenu() -> NSMenu {
        let menu = NSMenu(title: "Keyameleon")
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
                ?? "No activity observed yet"
        let activeKeyboardAssignmentValue = keyboardAssignmentMenuValue(
            switchingOutcome.currentKeyboardAssignment
        )
        let currentInputSourceValue =
            switchingOutcome.currentInputSourceName
                ?? "—"

        let statusItem = NSMenuItem(
            title: "Switching Status: \(switchingStatusName(switchingOutcome.switchingStatus))",
            action: nil,
            keyEquivalent: ""
        )
        statusItem.isEnabled = false
        statusItem.setAccessibilityLabel("Switching Status")
        statusItem.setAccessibilityValue(switchingStatusName(switchingOutcome.switchingStatus))
        menu.addItem(statusItem)

        if let reason = switchingOutcome.temporarilyUnavailableReasons.first {
            let reasonItem = NSMenuItem(
                title: "Detected reason: \(unavailableReasonName(reason))",
                action: nil,
                keyEquivalent: ""
            )
            reasonItem.isEnabled = false
            reasonItem.setAccessibilityLabel("Detected reason:")
            reasonItem.setAccessibilityValue(unavailableReasonName(reason))
            menu.addItem(reasonItem)

            let recoveryItem = NSMenuItem(
                title: "Resumes automatically when macOS allows Activity-Triggered Switching.",
                action: nil,
                keyEquivalent: ""
            )
            recoveryItem.isEnabled = false
            menu.addItem(recoveryItem)
        }

        addUncleanExitNoticeIfNeeded(to: menu)

        let activeKeyboardItem = NSMenuItem(
            title: "Active Physical Keyboard: \(activePhysicalKeyboardValue)",
            action: nil,
            keyEquivalent: ""
        )
        activeKeyboardItem.isEnabled = false
        activeKeyboardItem.setAccessibilityLabel("Active")
        activeKeyboardItem.setAccessibilityValue(activePhysicalKeyboardValue)
        menu.addItem(activeKeyboardItem)

        let assignmentItem = NSMenuItem(
            title: "Keyboard Assignment: \(activeKeyboardAssignmentValue)",
            action: nil,
            keyEquivalent: ""
        )
        assignmentItem.isEnabled = false
        assignmentItem.setAccessibilityLabel("Keyboard Assignment")
        assignmentItem.setAccessibilityValue(activeKeyboardAssignmentValue)
        menu.addItem(assignmentItem)

        let currentInputSourceItem = NSMenuItem(
            title: "Current Input Source: \(currentInputSourceValue)",
            action: nil,
            keyEquivalent: ""
        )
        currentInputSourceItem.isEnabled = false
        currentInputSourceItem.setAccessibilityLabel("Current Input Source")
        currentInputSourceItem.setAccessibilityValue(currentInputSourceValue)
        menu.addItem(currentInputSourceItem)

        if let mismatch = switchingOutcome.mismatch {
            let assignedItem = NSMenuItem(
                title: "Assigned Input Source: \(mismatch.assignedName)",
                action: nil,
                keyEquivalent: ""
            )
            assignedItem.isEnabled = false
            menu.addItem(assignedItem)

            let restoreItem = NSMenuItem(
                title: "Later Activation Activity restores the Keyboard Assignment.",
                action: nil,
                keyEquivalent: ""
            )
            restoreItem.isEnabled = false
            menu.addItem(restoreItem)
        }

        let actionItems = setupModel.physicalKeyboardActionConditions
        if !actionItems.isEmpty {
            menu.addItem(.separator())
            for actionItem in actionItems {
                let item = NSMenuItem(
                    title: physicalKeyboardActionConditionTitle(actionItem),
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
                title: "Resume Activity-Triggered Switching",
                action: #selector(resumeActivityTriggeredSwitching(_:)),
                keyEquivalent: ""
            )
            resumeItem.target = self
            menu.addItem(resumeItem)
        } else if switchingOutcome.hasAction(.pause) {
            let pauseItem = NSMenuItem(
                title: "Pause Activity-Triggered Switching",
                action: #selector(pauseActivityTriggeredSwitching(_:)),
                keyEquivalent: ""
            )
            pauseItem.target = self
            menu.addItem(pauseItem)
        }

        menu.addItem(.separator())

        let openItem = NSMenuItem(
            title: "Open Keyameleon…",
            action: #selector(openKeyameleon(_:)),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        if !setupModel.isSetupComplete {
            let continueSetupItem = NSMenuItem(
                title: "Continue Setup…",
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
                title: "Open System Settings",
                action: #selector(openSystemSettings(_:)),
                keyEquivalent: ""
            )
            openSystemSettingsItem.target = self
            menu.addItem(openSystemSettingsItem)

            let checkAgainItem = NSMenuItem(
                title: "Check Again",
                action: #selector(checkAgain(_:)),
                keyEquivalent: ""
            )
            checkAgainItem.target = self
            menu.addItem(checkAgainItem)
        }

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let checkForUpdatesItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates(_:)),
            keyEquivalent: ""
        )
        checkForUpdatesItem.target = self
        checkForUpdatesItem.isEnabled = generalSettingsModel.canCheckForUpdates
        menu.addItem(checkForUpdatesItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Keyameleon",
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
        button.setAccessibilityLabel("Keyameleon")
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
        let hasItemConditionsNeedingAction = !setupModel.physicalKeyboardActionConditions.isEmpty
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
                systemSymbolName: systemSymbolName(for: mark),
                accessibilityDescription: "Keyameleon"
            )
            ?? NSImage(
                systemSymbolName: systemSymbolName(for: .ready),
                accessibilityDescription: "Keyameleon"
            )
        image?.isTemplate = true
        button.image = image
        button.toolTip = menuBarIconAccessibilityDescription(for: mark)
        button.setAccessibilityLabel("Keyameleon")
    }

    private func keyboardAssignmentMenuValue(
        _ assignment: ActivityTriggeredSwitchingKeyboardAssignment
    ) -> String {
        switch assignment {
        case .none:
            "—"
        case .unassigned:
            "Unassigned"
        case let .assigned(name):
            name
        case .unavailable:
            "Unavailable Keyboard Assignment"
        case let .unsupported(reason):
            "Unsupported — \(unsupportedReasonName(reason))"
        }
    }

    private func observePresentationChanges() {
        withObservationTracking {
            _ = activityTriggeredSwitching.outcome
            _ = setupModel.physicalKeyboards
            _ = setupModel.isSetupComplete
            _ = setupModel.physicalKeyboardActionConditions
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
            title: "Keyameleon did not exit cleanly.",
            action: nil,
            keyEquivalent: ""
        )
        noticeItem.isEnabled = false
        noticeItem.setAccessibilityLabel("Keyameleon did not exit cleanly.")
        noticeItem.setAccessibilityValue(
            "Review local Diagnostic Data. Keyameleon sends no notification for an unclean exit."
        )
        menu.addItem(noticeItem)

        let reviewItem = NSMenuItem(
            title: "Review Diagnostics…",
            action: #selector(reviewDiagnostics(_:)),
            keyEquivalent: ""
        )
        reviewItem.target = self
        menu.addItem(reviewItem)

        let dismissItem = NSMenuItem(
            title: "Dismiss Diagnostics Notice",
            action: #selector(dismissDiagnosticsNotice(_:)),
            keyEquivalent: ""
        )
        dismissItem.target = self
        menu.addItem(dismissItem)
    }

    private func switchingStatusName(_ status: SwitchingStatus) -> String {
        switch status {
        case .ready:
            "Ready"
        case .permissionRequired:
            "Permission Required"
        case .paused:
            "Paused"
        case .temporarilyUnavailable:
            "Temporarily Unavailable"
        }
    }

    private func unavailableReasonName(_ reason: SwitchingUnavailableReason) -> String {
        switch reason {
        case .sleeping:
            "macOS is asleep"
        case .inactiveSession:
            "The user session is inactive"
        case .secureInput:
            "Secure Input is active"
        case .protectedDataUnavailable:
            "Protected data is unavailable"
        }
    }

    private func unsupportedReasonName(_ reason: PhysicalKeyboardUnsupportedReason) -> String {
        switch reason {
        case .missingIdentity:
            "Physical Keyboard Identity unavailable"
        case .unstableIdentity:
            "Physical Keyboard Identity unstable"
        case .sharedIdentity:
            "Physical Keyboard Identity shared"
        case .ambiguousIdentity:
            "Physical Keyboard Identity ambiguous"
        }
    }

    private func physicalKeyboardActionConditionTitle(
        _ condition: PhysicalKeyboardActionCondition
    ) -> String {
        switch condition {
        case let .unassigned(name):
            "Needs action: \(name) — Unassigned"
        case let .unavailableKeyboardAssignment(name):
            "Needs action: \(name) — Unavailable Keyboard Assignment"
        }
    }

    func systemSymbolName(for mark: MenuBarIconMark) -> String {
        switch mark {
        case .ready:
            "keyboard"
        case .permissionRequired:
            "keyboard.badge.ellipsis"
        case .temporarilyUnavailable:
            "moon.zzz"
        case .paused:
            "pause.circle"
        case .warning:
            "exclamationmark.triangle"
        }
    }

    func menuBarIconAccessibilityDescription(for mark: MenuBarIconMark) -> String {
        switch mark {
        case .ready:
            "Keyameleon"
        case .permissionRequired:
            "Keyameleon — Permission Required"
        case .temporarilyUnavailable:
            "Keyameleon — Temporarily Unavailable"
        case .paused:
            "Keyameleon — Paused"
        case .warning:
            "Keyameleon — Action needed"
        }
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
