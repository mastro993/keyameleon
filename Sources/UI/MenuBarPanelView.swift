import SwiftUI

struct MenuBarPanelActions {
    var openAbout: () -> Void
    var openSettings: () -> Void
    var quit: () -> Void
    var closePanel: () -> Void
}

/// Live menu-bar surface hosted in the native Liquid Glass popover.
///
/// The popover supplies the panel glass. Content uses a compact header,
/// assignment cards, and full-width action rows.
@MainActor
struct KeyameleonMenuBarPanelView: View {
    private let setupModel: KeyameleonSetupModel
    private let switching: ActivityTriggeredSwitching
    private let actions: MenuBarPanelActions
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @FocusState private var focusedTarget: MenuBarPanelAccessibility.FocusTarget?

    init(
        setupModel: KeyameleonSetupModel,
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
                focusedTarget: $focusedTarget,
                perform: perform
            )

            Divider()
                .opacity(0.22)

            MenuBarAssignmentSection(
                list: content.assignmentList,
                emphasis: chrome.assignmentEmphasis,
                focusedTarget: $focusedTarget
            )
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 10)

            MenuBarActionList(
                actions: content.footer.actions,
                focusedTarget: $focusedTarget,
                perform: perform
            )
        }
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
            Color(nsColor: .windowBackgroundColor)
        }
    }

    private func makeContent() -> MenuBarPanelContent {
        MenuBarPanelContent(
            outcome: switching.outcome,
            physicalKeyboards: setupModel.physicalKeyboards,
            assignedInputSourceNames: assignedInputSourceNames,
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
        case .about:
            actions.openAbout()
        case .openSystemSettings:
            setupModel.openSystemSettings()
        case .checkAgain:
            switching.checkAgain()
        case .settings:
            actions.openSettings()
        case .quit:
            actions.quit()
        }
    }
}

struct MenuBarPanelHeader: View {
    let openAction: MenuBarPanelContent.Action
    var focusedTarget: FocusState<MenuBarPanelAccessibility.FocusTarget?>.Binding
    let perform: (MenuBarPanelContent.Action) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Keyameleon")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                perform(openAction)
            } label: {
                Image(systemName: "info.circle.fill")
                    .font(.body)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 22, height: 22)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            .focusable()
            .focused(focusedTarget, equals: .about)
            .help(openAction.title)
            .accessibilityLabel(openAction.title)
            .accessibilityIdentifier("menu-bar-about")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 9)
        .accessibilityElement(children: .contain)
    }
}
