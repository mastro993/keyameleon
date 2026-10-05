import SwiftUI

struct MenuBarPanelActions {
    var openAbout: () -> Void
    var continueSetup: () -> Void
    var openSettings: () -> Void
    var quit: () -> Void
    var closePanel: () -> Void
}

/// Live menu-bar surface hosted in the native Liquid Glass popover.
///
/// The popover supplies the panel glass. Content uses a compact header,
/// assignment cards, and full-width action rows.
@MainActor
struct MenuBarPanelView: View {
    private let setupModel: SetupModel
    private let switching: ActivityTriggeredSwitching
    private let actions: MenuBarPanelActions
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @FocusState private var focusedTarget: MenuBarPanelAccessibility.FocusTarget?

    init(
        setupModel: SetupModel,
        switching: ActivityTriggeredSwitching,
        actions: MenuBarPanelActions
    ) {
        self.setupModel = setupModel
        self.switching = switching
        self.actions = actions
    }

    var body: some View {
        let content = makeContent()
        let chrome = MenuBarPanelChrome.resolve(
            reduceTransparency: reduceTransparency,
            increasedContrast: colorSchemeContrast == .increased
        )
        let accessibility = content.accessibility

        VStack(alignment: .leading, spacing: 0) {
            MenuBarPanelHeader(
                openAction: content.footer.about,
                pausedMarker: content.pausedMarker,
                focusedTarget: $focusedTarget,
                perform: perform
            )

            Divider()
                .opacity(Theme.Menu.separatorOpacity)

            PersistenceFailureNotice(model: setupModel)

            if let notice = content.notice {
                MenuBarPanelNoticeView(
                    notice: notice,
                    focusedTarget: $focusedTarget,
                    perform: perform
                )
            }

            if content.assignmentList.emptyTitle == nil || !setupModel.hasPersistenceFailure {
                MenuBarAssignmentSection(
                    list: content.assignmentList,
                    emphasis: chrome.assignmentEmphasis,
                    focusedTarget: $focusedTarget
                )
                .padding(.vertical, Theme.Menu.sectionInset)
            }

            Divider()
                .opacity(Theme.Menu.separatorOpacity)

            MenuBarActionList(
                actions: content.footer.actions,
                focusedTarget: $focusedTarget,
                perform: perform
            )
        }
        .padding(.horizontal, Theme.Menu.outerInset)
        .padding(.bottom, Theme.Menu.bottomInset)
        .frame(width: MenuBarPanelContent.panelWidth, alignment: .leading)
        .background(panelBackground(chrome.surface))
        .focusable()
        .focused($focusedTarget, equals: .container)
        .focusEffectDisabled(focusedTarget == .container)
        .defaultFocus($focusedTarget, .container)
        .focusSection()
        .onKeyPress { press in
            guard press.key == .tab,
                  focusedTarget == nil || focusedTarget == .container
            else {
                return .ignored
            }

            let order = accessibility.keyboardFocusOrder
            focusedTarget = press.modifiers.contains(.shift) ? order.last : order.first
            return focusedTarget == nil ? .ignored : .handled
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            // The popover reuses one content view across shows, so a row a pointer
            // click focused would still hold focus and stay ringed on reopen.
            focusedTarget = .container
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibility.panel.label)
        .accessibilityValue(accessibility.panel.value ?? "")
        .accessibilityIdentifier("menu-bar-panel")
    }

    @ViewBuilder
    private func panelBackground(_ surface: MenuBarPanelSurface) -> some View {
        switch surface {
        case .liquidGlass:
            Color.clear
        case .opaque:
            Rectangle().fill(.background)
        }
    }

    private func makeContent() -> MenuBarPanelContent {
        MenuBarPanelContent(
            outcome: switching.outcome,
            physicalKeyboards: setupModel.physicalKeyboards,
            assignedInputSources: assignedInputSources,
            marketingVersion: Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String,
            isSetupComplete: setupModel.isSetupComplete
        )
    }

    private var assignedInputSources: [PhysicalKeyboardRecordID: EligibleInputSource] {
        Dictionary(
            uniqueKeysWithValues: setupModel.physicalKeyboards.compactMap { physicalKeyboard in
                setupModel.assignedInputSource(for: physicalKeyboard)
                    .map { (physicalKeyboard.id, $0) }
            }
        )
    }

    func perform(_ action: MenuBarPanelContent.Action) {
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
        case .about:
            actions.openAbout()
        case .openSystemSettings:
            setupModel.openSystemSettings()
        case .checkAgain:
            switching.checkAgain()
        case .retryNow:
            switching.retryNow()
        case .continueSetup:
            actions.continueSetup()
        case .settings:
            actions.openSettings()
        case .quit:
            actions.quit()
        }
    }
}

struct MenuBarPanelHeader: View {
    let openAction: MenuBarPanelContent.Action
    let pausedMarker: String?
    var focusedTarget: FocusState<MenuBarPanelAccessibility.FocusTarget?>.Binding
    let perform: (MenuBarPanelContent.Action) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Menu.headerSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Menu.headerSpacing) {
                Text("Keyameleon")
                    .font(Theme.Typography.menuHeading)
                    .foregroundStyle(.primary)

                if let pausedMarker {
                    Text(pausedMarker)
                        .font(Theme.Typography.body)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(openAction.title, systemImage: "info.circle.fill") {
                perform(openAction)
            }
            .labelStyle(.iconOnly)
            .imageScale(.large)
            .font(Theme.Typography.body)
            .symbolRenderingMode(.monochrome)
            .frame(width: Theme.Menu.aboutSize, height: Theme.Menu.aboutSize)
            .contentShape(.circle)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .focusable()
            .focused(focusedTarget, equals: .about)
            .help(openAction.title)
            .accessibilityLabel(openAction.title)
            .accessibilityIdentifier("menu-bar-about")
        }
        .padding(.horizontal, Theme.Menu.innerInset)
        .frame(minHeight: Theme.Menu.headerHeight)
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
#Preview("Menu-bar panel") {
    let fixture = PreviewFixtures.setup(.assignmentsPopulated)
    MenuBarPanelView(
        setupModel: fixture.model,
        switching: fixture.switching,
        actions: PreviewFixtures.panelActions()
    )
}

#Preview("Menu-bar header") {
    @Previewable @FocusState var focusedTarget: MenuBarPanelAccessibility.FocusTarget?
    MenuBarPanelHeader(
        openAction: PreviewFixtures.aboutAction(),
        pausedMarker: nil,
        focusedTarget: $focusedTarget,
        perform: { _ in }
    )
    .frame(width: MenuBarPanelContent.panelWidth)
}

#Preview("Menu-bar header paused") {
    @Previewable @FocusState var focusedTarget: MenuBarPanelAccessibility.FocusTarget?
    MenuBarPanelHeader(
        openAction: PreviewFixtures.aboutAction(),
        pausedMarker: "(Paused)",
        focusedTarget: $focusedTarget,
        perform: { _ in }
    )
    .frame(width: MenuBarPanelContent.panelWidth)
}
#endif
