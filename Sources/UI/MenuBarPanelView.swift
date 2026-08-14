import SwiftUI

struct MenuBarPanelActions {
    var openKeyameleon: () -> Void
    var openSettings: () -> Void
    var checkForUpdates: () -> Void
    var quit: () -> Void
    var closePanel: () -> Void
}

/// Live Menu first surface hosted in the native Liquid Glass popover.
///
/// The popover supplies the panel glass. The panel body is the keyboard list
/// and footer only. Other actions live in the overflow menu.
@MainActor
struct KeyameleonMenuBarPanelView: View {
    private let setupModel: KeyameleonSetupModel
    private let switching: ActivityTriggeredSwitching
    @ObservedObject private var generalSettingsModel: KeyameleonGeneralSettingsModel
    private let actions: MenuBarPanelActions

    init(
        setupModel: KeyameleonSetupModel,
        switching: ActivityTriggeredSwitching,
        generalSettingsModel: KeyameleonGeneralSettingsModel,
        actions: MenuBarPanelActions
    ) {
        self.setupModel = setupModel
        self.switching = switching
        _generalSettingsModel = ObservedObject(wrappedValue: generalSettingsModel)
        self.actions = actions
    }

    var body: some View {
        let content = makeContent()

        VStack(alignment: .leading, spacing: 0) {
            MenuBarAssignmentSection(list: content.assignmentList)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 4)

            footer(content.footer)
        }
        .frame(width: MenuBarPanelContent.panelWidth, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("menu-bar-panel")
    }

    private func makeContent() -> MenuBarPanelContent {
        MenuBarPanelContent(
            outcome: switching.outcome,
            physicalKeyboards: setupModel.physicalKeyboards,
            assignedInputSourceNames: assignedInputSourceNames,
            canCheckForUpdates: generalSettingsModel.canCheckForUpdates,
            marketingVersion: Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String
        )
    }

    private var assignedInputSourceNames: [PhysicalKeyboardRecordID: String] {
        Dictionary(
            uniqueKeysWithValues: setupModel.physicalKeyboards.compactMap { physicalKeyboard in
                setupModel.assignedInputSourceName(for: physicalKeyboard)
                    .map { (physicalKeyboard.id, $0) }
            }
        )
    }

    private func footer(_ footer: MenuBarPanelContent.Footer) -> some View {
        HStack {
            Text(footer.versionText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Version")
                .accessibilityValue(footer.versionText)
            Spacer()
            HStack(spacing: 6) {
                MenuBarSettingsButton {
                    perform(footer.openKeyameleon)
                }
                .fixedSize()

                MenuBarOverflowButton(
                    actions: footer.overflowActions,
                    perform: perform,
                    closePanel: actions.closePanel
                )
                .fixedSize()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.separator)
                .frame(height: 1)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
    }

    private func perform(_ action: MenuBarPanelContent.Action) {
        if action.closesPanel {
            actions.closePanel()
        }

        switch action.id {
        case .pause:
            switching.pause()
        case .resume:
            switching.resume()
        case .requestPermission:
            setupModel.requestPermission()
        case .openKeyameleon:
            actions.openKeyameleon()
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
        }
    }
}
