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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @FocusState private var focusedTarget: MenuBarPanelAccessibility.FocusTarget?

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
        let chrome = MenuBarPanelChrome.resolve(
            reduceTransparency: reduceTransparency,
            increasedContrast: colorSchemeContrast == .increased
        )
        let accessibility = content.accessibility

        VStack(alignment: .leading, spacing: 0) {
            MenuBarAssignmentSection(
                list: content.assignmentList,
                emphasis: chrome.assignmentEmphasis,
                focusedTarget: $focusedTarget
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)

            footer(content.footer)
        }
        .frame(width: MenuBarPanelContent.panelWidth, alignment: .leading)
        .background(panelBackground(chrome.surface))
        .focusSection()
        .modifier(
            MenuBarPanelDefaultFocus(
                target: accessibility.keyboardFocusOrder.first,
                focusedTarget: $focusedTarget
            )
        )
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
                .accessibilityValue(footer.versionAccessibilityValue)
            Spacer()
            HStack(spacing: 6) {
                MenuBarSettingsButton {
                    perform(footer.openKeyameleon)
                }
                .fixedSize()
                .focusable()
                .focused($focusedTarget, equals: .openKeyameleon)

                MenuBarOverflowButton(
                    actions: footer.overflowActions,
                    perform: perform,
                    closePanel: actions.closePanel
                )
                .fixedSize()
                .focusable()
                .focused($focusedTarget, equals: .overflow)
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

private struct MenuBarPanelDefaultFocus: ViewModifier {
    let target: MenuBarPanelAccessibility.FocusTarget?
    var focusedTarget: FocusState<MenuBarPanelAccessibility.FocusTarget?>.Binding

    func body(content: Content) -> some View {
        if let target {
            content.defaultFocus(focusedTarget, target)
        } else {
            content
        }
    }
}
