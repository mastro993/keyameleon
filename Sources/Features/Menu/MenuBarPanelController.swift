import AppKit
import SwiftUI

@MainActor
final class MenuBarPanelController: NSObject, NSMenuDelegate {
    let menu = NSMenu()

    private let setupModel: SetupModel
    private let switching: ActivityTriggeredSwitching
    private let generalSettingsModel: GeneralSettingsModel
    private let actions: MenuBarPanelActions

    init(
        setupModel: SetupModel,
        switching: ActivityTriggeredSwitching,
        generalSettingsModel: GeneralSettingsModel,
        actions: MenuBarPanelActions
    ) {
        self.setupModel = setupModel
        self.switching = switching
        self.generalSettingsModel = generalSettingsModel
        self.actions = actions
        super.init()
        menu.autoenablesItems = false
        menu.delegate = self
        refresh()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        generalSettingsModel.refresh()
        switching.checkAgain()
        refresh()
    }

    func close() {
        menu.cancelTracking()
    }

    func refresh() {
        let keyboards = setupModel.physicalKeyboards
        let assignedInputSources = Dictionary(
            uniqueKeysWithValues: keyboards.compactMap { keyboard in
                setupModel.assignedInputSource(for: keyboard).map { (keyboard.id, $0) }
            }
        )
        let content = MenuBarPanelContent(
            outcome: switching.outcome,
            physicalKeyboards: keyboards,
            assignedInputSources: assignedInputSources,
            currentInputSourceIdentifier: setupModel.currentInputSourceIdentifier,
            marketingVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            isSetupComplete: setupModel.isSetupComplete,
            canCheckForUpdates: generalSettingsModel.canCheckForUpdates
        )

        var desired = [NSMenuItem]()
        let headingItem = item(id: "heading") { .sectionHeader(title: content.headerTitle) }
        headingItem.title = content.headerTitle
        desired.append(headingItem)

        let notice: MenuBarPanelNotice?
        if (setupModel.persistenceError ?? switching.persistenceError) != nil {
            notice = MenuBarPanelNotice(
                title: "Saved keyboards unavailable",
                detail: "Retry to recover saved keyboard data.",
                action: .init(id: .retryPersistence, title: "Retry", isEnabled: true),
                tone: .warning
            )
        } else {
            notice = content.notice
        }
        if let notice {
            let noticeItem = item(for: notice.action, id: "notice")
            updateHostedView(MenuBarPanelNoticeView(notice: notice) { [weak self] id in
                guard notice.action.isEnabled else { return }
                self?.close()
                self?.perform(id)
            }, in: noticeItem)
            desired.append(noticeItem)
        } else {
            let section = MenuBarAssignmentSection(
                list: content.assignmentList,
                emphasis: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
                    ? .highContrast : .standard
            )
            .padding(.horizontal, Theme.Menu.listInset)
            .frame(width: MenuBarPanelContent.panelWidth)
            .padding(.vertical, Theme.Menu.sectionInset)
            let keyboardItem = item(id: "keyboards") {
                NSMenuItem(title: "Keyboards", action: nil, keyEquivalent: "")
            }
            updateHostedView(section, in: keyboardItem)
            desired.append(keyboardItem)
        }

        desired.append(separator(id: "after-keyboards"))
        for action in content.footer.actions {
            if action.id == .quit {
                desired.append(separator(id: "before-quit"))
            }
            desired.append(item(for: action))
        }
        let desiredIDs = Set(desired.compactMap(\.identifier))
        for existing in menu.items.reversed() where existing.identifier.map({ !desiredIDs.contains($0) }) ?? true {
            menu.removeItem(existing)
        }
        for (index, wanted) in desired.enumerated() {
            guard index >= menu.numberOfItems || menu.item(at: index) !== wanted else { continue }
            if menu.index(of: wanted) >= 0 {
                menu.removeItem(wanted)
            }
            menu.insertItem(wanted, at: index)
        }
    }

    private func item(id: String, create: () -> NSMenuItem) -> NSMenuItem {
        let identifier = NSUserInterfaceItemIdentifier("menu-bar-\(id)")
        let item = menu.items.first { $0.identifier == identifier } ?? create()
        item.identifier = identifier
        return item
    }

    private func separator(id: String) -> NSMenuItem {
        item(id: id) { .separator() }
    }

    private func item(for action: MenuBarPanelContent.Action, id: String? = nil) -> NSMenuItem {
        let item = item(id: id ?? "action-\(action.id.rawValue)") {
            NSMenuItem(title: action.title, action: #selector(performMenuItem(_:)), keyEquivalent: "")
        }
        item.title = action.title
        item.action = #selector(performMenuItem(_:))
        item.target = self
        item.representedObject = action.id.rawValue
        item.isEnabled = action.isEnabled
        item.keyEquivalent = action.id.shortcut?.rawValue ?? ""
        item.keyEquivalentModifierMask = action.id.shortcut == nil ? [] : [.command]
        return item
    }

    private func updateHostedView<Content: View>(_ content: Content, in item: NSMenuItem) {
        let hosted: NSHostingView<Content>
        if let existing = item.view as? NSHostingView<Content> {
            existing.rootView = content
            hosted = existing
        } else {
            hosted = NSHostingView(rootView: content)
            hosted.autoresizingMask = [.width]
            item.view = hosted
        }
        hosted.frame.size = NSSize(
            width: MenuBarPanelContent.panelWidth,
            height: hosted.fittingSize.height
        )
    }

    @objc private func performMenuItem(_ item: NSMenuItem) {
        guard let rawID = item.representedObject as? String,
              let id = MenuBarPanelActionID(rawValue: rawID) else { return }
        perform(id)
    }

    private func perform(_ id: MenuBarPanelActionID) {
        switch id {
        case .pause: switching.pause()
        case .resume: switching.resume()
        case .requestPermission: setupModel.requestPermission()
        case .openSystemSettings: setupModel.openSystemSettings()
        case .checkAgain: switching.checkAgain()
        case .retryNow: switching.retryNow()
        case .retryPersistence: setupModel.retryPersistenceOperation()
        case .continueSetup: actions.continueSetup()
        case .settings: actions.openSettings()
        case .checkForUpdates: actions.checkForUpdates()
        case .quit: actions.quit()
        }
    }
}
