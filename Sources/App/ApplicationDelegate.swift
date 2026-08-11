import AppKit
@preconcurrency import SwiftData

@MainActor
final class KeyameleonApplicationDelegate: NSObject, NSApplicationDelegate {
    private let setupModel: KeyameleonSetupModel
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
        self.setupModel.refreshPermission()
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

        let inputSources = SystemInputSourceProvider()
        let isUITesting = ProcessInfo.processInfo.arguments.contains(
            "--reset-guided-setup"
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
        self.init(
            permissionProvider: SystemListenPermissionProvider(),
            setupStore: setupStore,
            systemSettingsOpener: NSWorkspaceSystemSettingsOpener(),
            physicalKeyboardRecordStore: SwiftDataPhysicalKeyboardRecordStore(
                modelContext: modelContext
            ),
            designationStore: SwiftDataManualPhysicalKeyboardDesignationStore(
                modelContext: modelContext
            ),
            integrityKeyProvider: KeychainInstallationIntegrityKeyProvider(),
            inputSourceProvider: inputSources,
            inputSourceSelector: inputSources,
            physicalKeyboardEventObserver: SystemPhysicalKeyboardEventObserver(),
            inputSourceChangeObserver: SystemInputSourceChangeObserver(),
            diagnosticDataController: diagnosticDataController,
            operationalNotificationProvider: operationalNotificationProvider,
            notificationEpisodeStore: notificationEpisodeStore,
            notificationSetupStore: notificationSetupStore,
            notificationSettingsOpener: NSWorkspaceNotificationSettingsOpener(),
            uncleanExitStateStore: uncleanExitStateStore,
            // UI tests must not open Sparkle sheets that steal focus from lifecycle checks.
            startsUpdaterOnLaunch: !isUITesting,
            modelContainer: modelContainer,
            diagnosticModelContainer: diagnosticModelContainer
        )
    }

    init(
        permissionProvider: any ListenPermissionProviding = SystemListenPermissionProvider(),
        protectedStateProvider: any ProtectedStateProviding = SystemProtectedStateProvider(),
        setupStore: any SetupDecisionStoring = UserDefaultsSetupDecisionStore(),
        systemSettingsOpener: any SystemSettingsOpening = NSWorkspaceSystemSettingsOpener(),
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
        self.modelContainer = modelContainer
        self.diagnosticModelContainer = diagnosticModelContainer
        self.updateChecker = updateChecker
        self.lifecycleObserver = lifecycleObserver
        self.startsUpdaterOnLaunch = startsUpdaterOnLaunch
        self.uncleanExitStateStore = uncleanExitStateStore
        setupModel = KeyameleonSetupModel(
            permissionProvider: permissionProvider,
            protectedStateProvider: protectedStateProvider,
            setupStore: setupStore,
            systemSettingsOpener: systemSettingsOpener,
            inputSourceProvider: inputSourceProvider,
            inputSourceSelector: inputSourceSelector,
            physicalKeyboardRecordStore: physicalKeyboardRecordStore,
            physicalKeyboardEventObserver: physicalKeyboardEventObserver,
            inputSourceChangeObserver: inputSourceChangeObserver,
            designationStore: designationStore,
            integrityKeyProvider: integrityKeyProvider,
            diagnosticDataController: diagnosticDataController,
            operationalNotificationProvider: operationalNotificationProvider,
            notificationEpisodeStore: notificationEpisodeStore,
            notificationSetupStore: notificationSetupStore
        )
        generalSettingsModel = KeyameleonGeneralSettingsModel(
            launchAtLoginController: launchAtLoginController,
            updateChecker: updateChecker,
            diagnosticDataController: diagnosticDataController,
            operationalNotificationProvider: operationalNotificationProvider,
            notificationSettingsOpener: notificationSettingsOpener
        )

        super.init()

        setupModel.onChange = { [weak self] in
            self?.generalSettingsModel.refresh()
            self?.refreshMenuBarPresentation()
        }
        generalSettingsModel.onNotificationAuthorizationChange = { [weak self] in
            self?.setupModel.refreshNotificationAuthorization()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        uncleanExitStateStore.beginLaunch()
        lifecycleObserver.start { [weak self] event in
            self?.setupModel.handleLifecycleEvent(event)
        }
        setupModel.refreshPermission()
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
        setupModel.refreshPermission()
        generalSettingsModel.refresh()
        refreshMenuBarPresentation()
    }

    func applicationWillTerminate(_ notification: Notification) {
        uncleanExitStateStore.markCleanTermination()
        lifecycleObserver.stop()
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

        let statusItem = NSMenuItem(
            title: "Switching Status: \(switchingStatusName(setupModel.switchingStatus))",
            action: nil,
            keyEquivalent: ""
        )
        statusItem.isEnabled = false
        statusItem.setAccessibilityLabel("Switching Status")
        statusItem.setAccessibilityValue(switchingStatusName(setupModel.switchingStatus))
        menu.addItem(statusItem)

        if let reason = setupModel.temporaryUnavailableReason {
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

        let activePhysicalKeyboardName = setupModel.activePhysicalKeyboard?.name
            ?? "No activity observed yet"
        let activeKeyboardItem = NSMenuItem(
            title: "Active Physical Keyboard: \(activePhysicalKeyboardName)",
            action: nil,
            keyEquivalent: ""
        )
        activeKeyboardItem.isEnabled = false
        activeKeyboardItem.setAccessibilityLabel("Active")
        activeKeyboardItem.setAccessibilityValue(activePhysicalKeyboardName)
        menu.addItem(activeKeyboardItem)

        let assignmentItem = NSMenuItem(
            title: "Keyboard Assignment: \(assignmentMenuValue)",
            action: nil,
            keyEquivalent: ""
        )
        assignmentItem.isEnabled = false
        assignmentItem.setAccessibilityLabel("Keyboard Assignment")
        assignmentItem.setAccessibilityValue(assignmentMenuValue)
        menu.addItem(assignmentItem)

        let currentInputSourceItem = NSMenuItem(
            title: "Current Input Source: \(currentSourceMenuValue)",
            action: nil,
            keyEquivalent: ""
        )
        currentInputSourceItem.isEnabled = false
        currentInputSourceItem.setAccessibilityLabel("Current Input Source")
        currentInputSourceItem.setAccessibilityValue(currentSourceMenuValue)
        menu.addItem(currentInputSourceItem)

        if let mismatch = setupModel.activeInputSourceMismatch {
            let assignedItem = NSMenuItem(
                title: "Assigned Input Source: \(inputSourceName(for: mismatch.assignedInputSourceIdentifier))",
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

        if setupModel.isActivityTriggeredSwitchingPaused {
            let resumeItem = NSMenuItem(
                title: "Resume Activity-Triggered Switching",
                action: #selector(resumeActivityTriggeredSwitching(_:)),
                keyEquivalent: ""
            )
            resumeItem.target = self
            menu.addItem(resumeItem)
        } else {
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

        if setupModel.switchingStatus != .temporarilyUnavailable {
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
        setupModel.refreshPermission()
        refreshMenuBarPresentation()
    }

    @objc
    private func pauseActivityTriggeredSwitching(_ sender: Any?) {
        setupModel.pauseActivityTriggeredSwitching()
        refreshMenuBarPresentation()
    }

    @objc
    private func resumeActivityTriggeredSwitching(_ sender: Any?) {
        setupModel.resumeActivityTriggeredSwitching()
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
        let mark = setupModel.menuBarIconMark
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

    private var assignmentMenuValue: String {
        guard let activePhysicalKeyboard = setupModel.activePhysicalKeyboard else {
            return "—"
        }

        switch activePhysicalKeyboard.assignmentState {
        case .unassigned:
            return "Unassigned"
        case .assigned:
            return setupModel.assignedInputSourceName(for: activePhysicalKeyboard)
                ?? "Unavailable Keyboard Assignment"
        case let .unsupported(reason):
            return "Unsupported — \(unsupportedReasonName(reason))"
        }
    }

    private var currentSourceMenuValue: String {
        guard let identifier = setupModel.currentInputSourceIdentifier else {
            return "—"
        }

        return inputSourceName(for: identifier)
    }

    private func inputSourceName(for identifier: String) -> String {
        setupModel.eligibleInputSources.first { $0.identifier == identifier }?.name ?? identifier
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
