import SwiftUI

struct MenuBarPanelActions {
    var openKeyameleon: () -> Void
    var openSettings: () -> Void
    var checkForUpdates: () -> Void
    var quit: () -> Void
    var reviewDiagnostics: () -> Void
    var dismissDiagnosticsNotice: () -> Void
    var closePanel: () -> Void
}

/// Live Menu first surface hosted in the native Liquid Glass popover.
///
/// The popover supplies the panel glass. Quick Actions use glass buttons.
/// Other regions stay on the popover surface without stacked glass cards.
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
        let content = makeContent()

        VStack(alignment: .leading, spacing: 12) {
            quickActions(content.quickActions)

            if let recoveryBanner = content.recoveryBanner {
                recoveryBannerView(recoveryBanner)
            }

            MenuBarAssignmentSection(list: content.assignmentList)

            if let uncleanExitNotice = content.uncleanExitNotice {
                uncleanExitNoticeView(uncleanExitNotice)
            }

            footer(content.footer)
        }
        .padding(16)
        .frame(width: MenuBarPanelContent.panelWidth, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("menu-bar-panel")
        .onAppear {
            hasPendingUncleanExitNotice = uncleanExitStateStore.hasPendingUncleanExitNotice
        }
    }

    private func makeContent() -> MenuBarPanelContent {
        MenuBarPanelContent(
            outcome: switching.outcome,
            physicalKeyboards: setupModel.physicalKeyboards,
            assignedInputSourceNames: assignedInputSourceNames,
            canCheckForUpdates: generalSettingsModel.canCheckForUpdates,
            hasPendingUncleanExitNotice: hasPendingUncleanExitNotice,
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

    private func quickActions(_ quickActions: MenuBarPanelContent.QuickActions) -> some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button(quickActions.openKeyameleon.title) {
                    perform(quickActions.openKeyameleon)
                }
                .buttonStyle(.glassProminent)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("menu-bar-open-keyameleon")

                Button(quickActions.pauseOrResume.title) {
                    perform(quickActions.pauseOrResume)
                }
                .buttonStyle(.glass)
                .accessibilityIdentifier("menu-bar-pause-resume")
            }
        }
    }

    private func recoveryBannerView(
        _ banner: MenuBarPanelContent.RecoveryBanner
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(banner.statusName)
                .font(.headline)
            ForEach(banner.detailLines, id: \.self) { line in
                Text(line)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !banner.recoveryActions.isEmpty {
                HStack {
                    ForEach(banner.recoveryActions) { action in
                        Button(action.title) {
                            perform(action)
                        }
                        .disabled(!action.isEnabled)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Switching Status")
        .accessibilityValue(banner.statusName)
        .accessibilityIdentifier("menu-bar-recovery-banner")
    }

    private func uncleanExitNoticeView(
        _ notice: MenuBarPanelContent.UncleanExitNotice
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(notice.title)
                .font(.callout)
            Button(notice.dismiss.title) {
                perform(notice.dismiss)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(notice.title)
        .accessibilityValue(
            "Review local Diagnostic Data. Keyameleon sends no notification for an unclean exit."
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
            MenuBarOverflowButton(actions: footer.overflowActions, perform: perform)
                .frame(width: 44, height: 20)
        }
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
        case .reviewDiagnostics:
            actions.reviewDiagnostics()
            hasPendingUncleanExitNotice = uncleanExitStateStore.hasPendingUncleanExitNotice
        case .dismissDiagnosticsNotice:
            actions.dismissDiagnosticsNotice()
            hasPendingUncleanExitNotice = uncleanExitStateStore.hasPendingUncleanExitNotice
        }
    }
}
