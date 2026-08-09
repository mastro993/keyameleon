import AppKit

@MainActor
final class KeyameleonApplicationDelegate: NSObject, NSApplicationDelegate {
    private let setupModel: KeyameleonSetupModel
    private var statusItem: NSStatusItem?
    private var windowController: KeyameleonWindowController?

    private lazy var menuDelegate = KeyameleonMenuDelegate { [weak self] in
        self?.setupModel.refreshPermission()
    }

    override convenience init() {
        let setupStore = UserDefaultsSetupDecisionStore()
        if ProcessInfo.processInfo.arguments.contains(KeyameleonAppMetadata.uiTestingResetSetupLaunchArgument) {
            setupStore.resetForUITesting()
        }

        self.init(
            permissionProvider: SystemListenPermissionProvider(),
            setupStore: setupStore,
            systemSettingsOpener: NSWorkspaceSystemSettingsOpener()
        )
    }

    init(
        permissionProvider: any ListenPermissionProviding = SystemListenPermissionProvider(),
        setupStore: any SetupDecisionStoring = UserDefaultsSetupDecisionStore(),
        systemSettingsOpener: any SystemSettingsOpening = NSWorkspaceSystemSettingsOpener()
    ) {
        setupModel = KeyameleonSetupModel(
            permissionProvider: permissionProvider,
            setupStore: setupStore,
            systemSettingsOpener: systemSettingsOpener
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
        setupModel.beginGuidedSetup()
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
        onMenuWillOpen()
    }
}
