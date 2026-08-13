import SwiftUI

struct MenuBarPanelActions {
    var openKeyameleon: () -> Void
    var continueSetup: () -> Void
    var openSettings: () -> Void
    var checkForUpdates: () -> Void
    var quit: () -> Void
    var reviewDiagnostics: () -> Void
    var dismissDiagnosticsNotice: () -> Void
}

/// Live Menu first surface hosted in the native Liquid Glass popover.
///
/// The popover supplies glass. This view does not add stacked glass cards.
@MainActor
struct KeyameleonMenuBarPanelView: View {
    private let setupModel: KeyameleonSetupModel
    private let switching: ActivityTriggeredSwitching
    @ObservedObject private var generalSettingsModel: KeyameleonGeneralSettingsModel
    private let uncleanExitStateStore: any UncleanExitStateStoring
    private let actions: MenuBarPanelActions
    @State private var hasPendingUncleanExitNotice: Bool

    init(
        setupModel: KeyameleonSetupModel,
        switching: ActivityTriggeredSwitching,
        generalSettingsModel: KeyameleonGeneralSettingsModel,
        uncleanExitStateStore: any UncleanExitStateStoring,
        actions: MenuBarPanelActions
    ) {
        self.setupModel = setupModel
        self.switching = switching
        _generalSettingsModel = ObservedObject(wrappedValue: generalSettingsModel)
        self.uncleanExitStateStore = uncleanExitStateStore
        self.actions = actions
        _hasPendingUncleanExitNotice = State(
            initialValue: uncleanExitStateStore.hasPendingUncleanExitNotice
        )
    }

    var body: some View {
        let content = MenuBarPanelContent(
            outcome: switching.outcome,
            actionConditions: setupModel.physicalKeyboardActionConditions,
            isSetupComplete: setupModel.isSetupComplete,
            canCheckForUpdates: generalSettingsModel.canCheckForUpdates,
            hasPendingUncleanExitNotice: hasPendingUncleanExitNotice
        )

        VStack(alignment: .leading, spacing: 8) {
            ForEach(content.items) { item in
                switch item.kind {
                case .status:
                    statusLine(item)
                case let .action(actionID, enabled):
                    Button(item.title) {
                        perform(actionID)
                    }
                    .disabled(!enabled)
                    .optionalKeyboardShortcut(shortcut(for: actionID))
                }
            }
        }
        .padding(16)
        .frame(width: MenuBarPanelContent.panelWidth, alignment: .leading)
        .accessibilityIdentifier("menu-bar-panel")
        .onAppear {
            hasPendingUncleanExitNotice = uncleanExitStateStore.hasPendingUncleanExitNotice
        }
    }

    @ViewBuilder
    private func statusLine(_ item: MenuBarPanelContent.Item) -> some View {
        let line = Text(item.title)
            .frame(maxWidth: .infinity, alignment: .leading)
        if let accessibilityLabel = item.accessibilityLabel {
            if let accessibilityValue = item.accessibilityValue {
                line
                    .accessibilityLabel(accessibilityLabel)
                    .accessibilityValue(accessibilityValue)
            } else {
                line.accessibilityLabel(accessibilityLabel)
            }
        } else {
            line
        }
    }

    private func perform(_ actionID: MenuBarPanelActionID) {
        switch actionID {
        case .pause:
            switching.pause()
        case .resume:
            switching.resume()
        case .openKeyameleon:
            actions.openKeyameleon()
        case .continueSetup:
            actions.continueSetup()
        case .openSystemSettings:
            setupModel.openSystemSettings()
        case .checkAgain:
            switching.checkAgain()
        case .settings:
            actions.openSettings()
        case .checkForUpdates:
            actions.checkForUpdates()
        case .quit:
            actions.quit()
        case .reviewDiagnostics:
            actions.reviewDiagnostics()
            hasPendingUncleanExitNotice = uncleanExitStateStore.hasPendingUncleanExitNotice
        case .dismissDiagnosticsNotice:
            actions.dismissDiagnosticsNotice()
            hasPendingUncleanExitNotice = uncleanExitStateStore.hasPendingUncleanExitNotice
        }
    }

    private func shortcut(for actionID: MenuBarPanelActionID) -> KeyboardShortcut? {
        switch actionID {
        case .settings:
            KeyboardShortcut(",", modifiers: .command)
        case .quit:
            KeyboardShortcut("q", modifiers: .command)
        default:
            nil
        }
    }
}

private extension View {
    @ViewBuilder
    func optionalKeyboardShortcut(_ shortcut: KeyboardShortcut?) -> some View {
        if let shortcut {
            self.keyboardShortcut(shortcut)
        } else {
            self
        }
    }
}
