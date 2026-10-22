import AppKit
import SwiftUI

/// The Settings window: a preference-style toolbar above the selected pane.
@MainActor
final class SettingsWindowController: NSWindowController, NSToolbarDelegate {
    private let selection: SettingsSelection
    private let toolbar = NSToolbar(identifier: "keyameleon.settings-toolbar")

    var selectedSection: SettingsSection {
        selection.section
    }

    init(
        model: GeneralSettingsModel,
        setupModel: SetupModel,
        appAssignmentsModel: AppAssignmentsModel,
        selection: SettingsSelection
    ) {
        self.selection = selection
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: Theme.Metrics.settingsWindowWidth,
                height: Theme.Metrics.settingsWindowHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.identifier = NSUserInterfaceItemIdentifier("keyameleon.settings-window")
        window.title = AppIdentity.current.name
        window.isRestorable = false
        window.isReleasedWhenClosed = false
        window.toolbarStyle = .preference
        window.contentView = NSHostingView(
            rootView: SettingsView(
                model: model,
                setupModel: setupModel,
                appAssignmentsModel: appAssignmentsModel,
                selection: selection
            )
        )

        super.init(window: window)

        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar
        showSelectedSection()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        guard let window else {
            return
        }

        showSelectedSection()
        if !window.isVisible {
            window.center()
        }
        super.showWindow(sender)
        window.makeKeyAndOrderFront(sender)
    }

    private func showSelectedSection() {
        toolbar.selectedItemIdentifier = NSToolbarItem.Identifier(selection.section.rawValue)
    }

    @objc
    private func selectSection(_ sender: NSToolbarItem) {
        guard let section = SettingsSection(rawValue: sender.itemIdentifier.rawValue) else {
            return
        }
        selection.section = section
        showSelectedSection()
    }

    // MARK: NSToolbarDelegate

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsSection.allCases.map { NSToolbarItem.Identifier($0.rawValue) }
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard let section = SettingsSection(rawValue: itemIdentifier.rawValue) else {
            return nil
        }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = String(localized: section.title)
        item.image = NSImage(systemSymbolName: section.systemImage, accessibilityDescription: nil)
        item.target = self
        item.action = #selector(selectSection(_:))
        return item
    }
}
