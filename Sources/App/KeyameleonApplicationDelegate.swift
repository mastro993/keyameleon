import AppKit
@preconcurrency import SwiftData

@MainActor
final class KeyameleonApplicationDelegate: NSObject, NSApplicationDelegate {
    private let setupModel: KeyameleonSetupModel
    private let updateChecker: any UpdateChecking
    private let startsUpdaterOnLaunch: Bool
    let generalSettingsModel: KeyameleonGeneralSettingsModel
    private var statusItem: NSStatusItem?
    private var windowController: KeyameleonWindowController?
    private let modelContainer: ModelContainer?
    /// Avoid replacing the opening menu while `menuNeedsUpdate` repopulates it.
    private var isPopulatingOpenMenu = false

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
    }

    override convenience init() {
        let setupStore = UserDefaultsSetupDecisionStore()
        if ProcessInfo.processInfo.arguments.contains(KeyameleonAppMetadata.uiTestingResetSetupLaunchArgument) {
            setupStore.resetForUITesting()
        }

        let modelContainer: ModelContainer
        do {
            modelContainer = try SwiftDataPhysicalKeyboardRecordStore.makeContainer()
        } catch {
            fatalError("SwiftData container failed for Physical Keyboard records: \(error)")
        }

        let modelContext = ModelContext(modelContainer)
        let inputSources = SystemInputSourceProvider()
        let isUITesting = ProcessInfo.processInfo.arguments.contains(
            KeyameleonAppMetadata.uiTestingResetSetupLaunchArgument
        )
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
            // UI tests must not open Sparkle sheets that steal focus from lifecycle checks.
            startsUpdaterOnLaunch: !isUITesting,
            modelContainer: modelContainer
        )
    }

    init(
        permissionProvider: any ListenPermissionProviding = SystemListenPermissionProvider(),
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
        launchAtLoginController: any LaunchAtLoginControlling = ServiceManagementLaunchAtLoginController(),
        updateChecker: any UpdateChecking = SparkleUpdateChecker(),
        startsUpdaterOnLaunch: Bool = true,
        modelContainer: ModelContainer? = nil
    ) {
        self.modelContainer = modelContainer
        self.updateChecker = updateChecker
        self.startsUpdaterOnLaunch = startsUpdaterOnLaunch
        setupModel = KeyameleonSetupModel(
            permissionProvider: permissionProvider,
            setupStore: setupStore,
            systemSettingsOpener: systemSettingsOpener,
            inputSourceProvider: inputSourceProvider,
            inputSourceSelector: inputSourceSelector,
            physicalKeyboardRecordStore: physicalKeyboardRecordStore,
            physicalKeyboardEventObserver: physicalKeyboardEventObserver,
            inputSourceChangeObserver: inputSourceChangeObserver,
            designationStore: designationStore,
            integrityKeyProvider: integrityKeyProvider
        )
        generalSettingsModel = KeyameleonGeneralSettingsModel(
            launchAtLoginController: launchAtLoginController,
            updateChecker: updateChecker
        )

        super.init()

        setupModel.onChange = { [weak self] in
            self?.refreshMenuBarPresentation()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
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
        refreshMenuBarPresentation()
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

        let statusItem = NSMenuItem(
            title: KeyameleonAppMetadata.switchingStatusMenuItemTitle(setupModel.switchingStatus),
            action: nil,
            keyEquivalent: ""
        )
        statusItem.isEnabled = false
        statusItem.setAccessibilityLabel("Switching Status")
        statusItem.setAccessibilityValue(setupModel.switchingStatus.displayName)
        menu.addItem(statusItem)

        let activeKeyboardItem = NSMenuItem(
            title: KeyameleonAppMetadata.activePhysicalKeyboardMenuItemTitle(
                setupModel.activePhysicalKeyboardMenuValue
            ),
            action: nil,
            keyEquivalent: ""
        )
        activeKeyboardItem.isEnabled = false
        activeKeyboardItem.setAccessibilityLabel(KeyameleonAppMetadata.activePhysicalKeyboardLabel)
        activeKeyboardItem.setAccessibilityValue(setupModel.activePhysicalKeyboardMenuValue)
        menu.addItem(activeKeyboardItem)

        let assignmentItem = NSMenuItem(
            title: KeyameleonAppMetadata.keyboardAssignmentMenuItemTitle(
                setupModel.activeKeyboardAssignmentMenuValue
            ),
            action: nil,
            keyEquivalent: ""
        )
        assignmentItem.isEnabled = false
        assignmentItem.setAccessibilityLabel(KeyameleonAppMetadata.keyboardAssignmentLabel)
        assignmentItem.setAccessibilityValue(setupModel.activeKeyboardAssignmentMenuValue)
        menu.addItem(assignmentItem)

        let currentInputSourceItem = NSMenuItem(
            title: KeyameleonAppMetadata.currentInputSourceMenuItemTitle(
                setupModel.currentInputSourceMenuValue
            ),
            action: nil,
            keyEquivalent: ""
        )
        currentInputSourceItem.isEnabled = false
        currentInputSourceItem.setAccessibilityLabel(KeyameleonAppMetadata.currentInputSourceLabel)
        currentInputSourceItem.setAccessibilityValue(setupModel.currentInputSourceMenuValue)
        menu.addItem(currentInputSourceItem)

        if let mismatch = setupModel.activeInputSourceMismatch {
            let assignedItem = NSMenuItem(
                title: "\(KeyameleonAppMetadata.assignedInputSourceLabel): \(mismatch.assignedName)",
                action: nil,
                keyEquivalent: ""
            )
            assignedItem.isEnabled = false
            menu.addItem(assignedItem)

            let restoreItem = NSMenuItem(
                title: mismatch.restorationExplanation,
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

        if setupModel.isActivityTriggeredSwitchingPaused {
            let resumeItem = NSMenuItem(
                title: KeyameleonAppMetadata.resumeActivityTriggeredSwitchingMenuItemTitle,
                action: #selector(resumeActivityTriggeredSwitching(_:)),
                keyEquivalent: ""
            )
            resumeItem.target = self
            menu.addItem(resumeItem)
        } else {
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
        if windowController == nil {
            windowController = KeyameleonWindowController(model: setupModel)
        }

        windowController?.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
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

        if !isPopulatingOpenMenu {
            statusItem.menu = makeMenu()
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
}

@MainActor
private final class KeyameleonMenuDelegate: NSObject, NSMenuDelegate {
    private let onMenuNeedsUpdate: @MainActor (NSMenu) -> Void

    init(onMenuNeedsUpdate: @escaping @MainActor (NSMenu) -> Void) {
        self.onMenuNeedsUpdate = onMenuNeedsUpdate
        super.init()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        // Refresh permission and observed Input Source before Menu first paints.
        onMenuNeedsUpdate(menu)
    }
}
