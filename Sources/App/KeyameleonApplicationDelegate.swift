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

    private lazy var menuDelegate = KeyameleonMenuDelegate { [weak self] in
        // Refresh only. Do not replace the open menu.
        self?.setupModel.refreshPermission()
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

        let inputSources = SystemInputSourceProvider()
        let isUITesting = ProcessInfo.processInfo.arguments.contains(
            KeyameleonAppMetadata.uiTestingResetSetupLaunchArgument
        )
        self.init(
            permissionProvider: SystemListenPermissionProvider(),
            setupStore: setupStore,
            systemSettingsOpener: NSWorkspaceSystemSettingsOpener(),
            physicalKeyboardRecordStore: SwiftDataPhysicalKeyboardRecordStore(
                modelContext: ModelContext(modelContainer)
            ),
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
            inputSourceChangeObserver: inputSourceChangeObserver
        )
        generalSettingsModel = KeyameleonGeneralSettingsModel(
            launchAtLoginController: launchAtLoginController,
            updateChecker: updateChecker
        )

        super.init()

        setupModel.onChange = { [weak self] in
            self?.refreshMenu()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupModel.refreshPermission()
        statusItem = makeStatusItem()
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
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu(title: KeyameleonAppMetadata.displayName)
        menu.autoenablesItems = false

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
                setupModel.activePhysicalKeyboard?.name
            ),
            action: nil,
            keyEquivalent: ""
        )
        activeKeyboardItem.isEnabled = false
        activeKeyboardItem.setAccessibilityLabel(KeyameleonAppMetadata.activePhysicalKeyboardLabel)
        activeKeyboardItem.setAccessibilityValue(
            setupModel.activePhysicalKeyboard?.name
                ?? KeyameleonAppMetadata.noActivityObservedYet
        )
        menu.addItem(activeKeyboardItem)

        if let mismatch = setupModel.activeInputSourceMismatch {
            let currentItem = NSMenuItem(
                title: "\(KeyameleonAppMetadata.currentInputSourceLabel): \(mismatch.currentName)",
                action: nil,
                keyEquivalent: ""
            )
            currentItem.isEnabled = false
            menu.addItem(currentItem)

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

        menu.delegate = menuDelegate

        return menu
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
        refreshMenu()
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

        button.image = NSImage(
            systemSymbolName: "keyboard",
            accessibilityDescription: KeyameleonAppMetadata.displayName
        )
        button.imagePosition = .imageOnly
        button.toolTip = KeyameleonAppMetadata.displayName
        button.setAccessibilityElement(true)
        button.setAccessibilityRole(.button)
        button.setAccessibilityLabel(KeyameleonAppMetadata.menuBarAccessibilityLabel)
        item.menu = makeMenu()
        return item
    }

    private func refreshMenu() {
        guard let statusItem else {
            return
        }

        statusItem.menu = makeMenu()
    }
}

@MainActor
private final class KeyameleonMenuDelegate: NSObject, NSMenuDelegate {
    private let onMenuWillOpen: @MainActor () -> Void

    init(onMenuWillOpen: @escaping @MainActor () -> Void) {
        self.onMenuWillOpen = onMenuWillOpen
        super.init()
    }

    func menuWillOpen(_ menu: NSMenu) {
        // Refresh permission and observed Input Source before Menu first paints.
        onMenuWillOpen()
    }
}
