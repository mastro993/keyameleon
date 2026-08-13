import SwiftUI

struct MenuBarPanelActions {
    var openKeyameleon: () -> Void
    var openSettings: () -> Void
    var checkForUpdates: () -> Void
    var quit: () -> Void
    var reviewDiagnostics: () -> Void
}

/// Live menu-bar surface hosted in the native Liquid Glass popover.
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
    @FocusState private var focusedAction: MenuBarPanelActionID?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

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
        let surface = MenuBarPanelChrome.surface(reduceTransparency: reduceTransparency)
        let emphasizeSeparators = MenuBarPanelChrome.prefersEmphasizedSeparators(
            increaseContrast: colorSchemeContrast == .increased
        )

        VStack(alignment: .leading, spacing: 12) {
            if let banner = content.recoveryBanner {
                MenuBarPanelRecoveryBannerView(
                    banner: banner,
                    focusedAction: $focusedAction,
                    perform: perform
                )
                panelSeparator(emphasized: emphasizeSeparators)
            }

            MenuBarPanelAssignmentListView(content: content)
            panelSeparator(emphasized: emphasizeSeparators)
            MenuBarPanelQuickActionsView(
                actions: content.quickActions,
                focusedAction: $focusedAction,
                perform: perform
            )
            panelSeparator(emphasized: emphasizeSeparators)
            MenuBarPanelFooterView(
                versionText: content.versionText,
                marketingVersion: content.marketingVersion,
                overflowActions: content.overflowActions,
                focusedAction: $focusedAction,
                perform: perform
            )
        }
        .padding(16)
        .frame(width: MenuBarPanelContent.panelWidth, alignment: .leading)
        .background(alignment: .bottomTrailing) {
            Button("Quit Keyameleon") {
                perform(.quit)
            }
            .keyboardShortcut("q", modifiers: .command)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
        .background {
            if surface == .opaque {
                Rectangle().fill(Color(nsColor: .windowBackgroundColor))
            }
        }
        .accessibilityIdentifier("menu-bar-panel")
        .onAppear {
            hasPendingUncleanExitNotice = uncleanExitStateStore.hasPendingUncleanExitNotice
            focusedAction = content.keyboardFocusOrder.first
        }
        .onChange(of: content.keyboardFocusOrder) { _, order in
            if let focusedAction, order.contains(focusedAction) {
                return
            }

            focusedAction = order.first
        }
    }

    private func makeContent() -> MenuBarPanelContent {
        MenuBarPanelContent(
            outcome: switching.outcome,
            physicalKeyboards: setupModel.physicalKeyboards,
            assignedInputSources: MenuBarPanelContent.assignedInputSources(
                from: setupModel.physicalKeyboards,
                names: setupModel.assignedInputSourceName(for:)
            ),
            canCheckForUpdates: generalSettingsModel.canCheckForUpdates,
            hasPendingUncleanExitNotice: hasPendingUncleanExitNotice,
            marketingVersion: MenuBarPanelContent.marketingVersion(from: .main)
        )
    }

    private func perform(_ actionID: MenuBarPanelActionID) {
        switch actionID {
        case .pause:
            switching.pause()
        case .resume:
            switching.resume()
        case .openKeyameleon:
            actions.openKeyameleon()
        case .openSystemSettings:
            setupModel.openSystemSettings()
        case .settings:
            actions.openSettings()
        case .checkForUpdates:
            actions.checkForUpdates()
        case .quit:
            actions.quit()
        case .reviewDiagnostics:
            actions.reviewDiagnostics()
            hasPendingUncleanExitNotice = uncleanExitStateStore.hasPendingUncleanExitNotice
        case .overflow:
            break
        }
    }

    private func panelSeparator(emphasized: Bool) -> some View {
        Divider()
            .opacity(emphasized ? 1 : 0.45)
    }
}

private struct MenuBarPanelRecoveryBannerView: View {
    let banner: MenuBarPanelContent.RecoveryBanner
    var focusedAction: FocusState<MenuBarPanelActionID?>.Binding
    let perform: (MenuBarPanelActionID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(banner.switchingStatusName)
                .font(.headline)
                .accessibilityLabel(banner.accessibilityLabel)
                .accessibilityValue(banner.accessibilityValue)
                .accessibilityHint(banner.detail ?? "")
            if let detail = banner.detail {
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            if let action = banner.action {
                Button(action.title) {
                    perform(action.id)
                }
                .disabled(!action.isEnabled)
                .focused(focusedAction, equals: action.id)
                .accessibilityLabel(action.accessibilityLabel)
                .accessibilityIdentifier("menu-bar-panel-recovery-action")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("menu-bar-panel-recovery")
    }
}

private struct MenuBarPanelAssignmentListView: View {
    let content: MenuBarPanelContent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(content.assignmentHeading)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("menu-bar-panel-assignments-heading")

            if let emptyAssignmentsMessage = content.emptyAssignmentsMessage {
                Text(emptyAssignmentsMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("menu-bar-panel-assignments-empty")
            } else if content.assignmentsScroll {
                ScrollView {
                    assignmentStack
                }
                .frame(
                    maxHeight: CGFloat(MenuBarPanelContent.visibleAssignmentLimit)
                        * MenuBarPanelContent.assignmentRowMinHeight
                )
                .focusable()
            } else {
                assignmentStack
            }
        }
        .accessibilityIdentifier("menu-bar-panel-assignments")
    }

    private var assignmentStack: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(content.assignmentRows) { row in
                MenuBarPanelAssignmentRowView(row: row)
            }
        }
    }
}

private struct MenuBarPanelAssignmentRowView: View {
    let row: MenuBarPanelContent.AssignmentRow

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbolName)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.physicalKeyboardName)
                    .font(.body)
                    .lineLimit(2)
                    .truncationMode(.tail)
                Text(row.assignedInputSourceName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                if let warningNote = row.warningNote {
                    Label(warningNote, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .opacity(row.isDimmed ? 0.55 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityValue(row.accessibilityValue)
        .accessibilityHint(row.accessibilityHint ?? "")
        .accessibilityAddTraits(.isStaticText)
        .focusable()
    }

    private var symbolName: String {
        switch row.conditionMark {
        case .active:
            "asterisk.circle.fill"
        case .connected:
            "circle"
        case .disconnected:
            "circle.slash"
        }
    }
}

private struct MenuBarPanelQuickActionsView: View {
    let actions: [MenuBarPanelContent.Action]
    var focusedAction: FocusState<MenuBarPanelActionID?>.Binding
    let perform: (MenuBarPanelActionID) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(actions) { action in
                quickActionButton(action)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("menu-bar-panel-quick-actions")
    }

    @ViewBuilder
    private func quickActionButton(_ action: MenuBarPanelContent.Action) -> some View {
        let button = Button(action.title) {
            perform(action.id)
        }
        .disabled(!action.isEnabled)
        .controlSize(.large)
        .frame(maxWidth: action.id == .openKeyameleon ? .infinity : nil)
        .focused(focusedAction, equals: action.id)
        .accessibilityLabel(action.accessibilityLabel)

        if action.id == .openKeyameleon {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }
}

private struct MenuBarPanelFooterView: View {
    let versionText: String
    let marketingVersion: String
    let overflowActions: [MenuBarPanelContent.Action]
    var focusedAction: FocusState<MenuBarPanelActionID?>.Binding
    let perform: (MenuBarPanelActionID) -> Void

    var body: some View {
        HStack {
            Text(versionText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Version")
                .accessibilityValue(marketingVersion)
                .accessibilityIdentifier("menu-bar-panel-version")
            Spacer()
            Menu("More", systemImage: "ellipsis.circle") {
                ForEach(Array(overflowActions.enumerated()), id: \.element.id) { index, action in
                    if action.id == .quit, index > 0 {
                        Divider()
                    }
                    overflowButton(action)
                }
            }
            .menuIndicator(.hidden)
            .labelStyle(.iconOnly)
            .focused(focusedAction, equals: .overflow)
            .accessibilityLabel("More")
            .accessibilityIdentifier("menu-bar-panel-overflow")
        }
    }

    @ViewBuilder
    private func overflowButton(_ action: MenuBarPanelContent.Action) -> some View {
        let button = Button(action.title) {
            perform(action.id)
        }
        .disabled(!action.isEnabled)
        .accessibilityLabel(action.accessibilityLabel)

        switch action.id {
        case .settings:
            button.keyboardShortcut(",", modifiers: .command)
        case .quit:
            button.keyboardShortcut("q", modifiers: .command)
        default:
            button
        }
    }
}
