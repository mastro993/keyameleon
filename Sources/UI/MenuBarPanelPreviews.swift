#if DEBUG
import SwiftUI

#Preview("Panel glass / light") {
    MenuBarPanelChromePreview(reduceTransparency: false, increasedContrast: false)
        .preferredColorScheme(.light)
}

#Preview("Panel opaque / dark") {
    MenuBarPanelChromePreview(reduceTransparency: true, increasedContrast: false)
        .preferredColorScheme(.dark)
}

#Preview("Panel contrast + long names") {
    MenuBarPanelChromePreview(
        reduceTransparency: false,
        increasedContrast: true,
        names: [
            "Keychron K2 HE ISO Nordic Traveler Custom Mechanical",
            "HHKB Professional Hybrid Type-S"
        ]
    )
}

#Preview("Panel five assignments") {
    MenuBarPanelChromePreview(count: 5)
}

#Preview("Panel overflow assignments") {
    MenuBarPanelChromePreview(count: 6)
}

private struct MenuBarPanelChromePreview: View {
    var reduceTransparency = false
    var increasedContrast = false
    var count = 0
    var names: [String] = []
    @FocusState private var focusedTarget: MenuBarPanelAccessibility.FocusTarget?

    var body: some View {
        let chrome = MenuBarPanelChrome.resolve(
            reduceTransparency: reduceTransparency,
            increasedContrast: increasedContrast
        )
        let keyboards = previewKeyboards()
        VStack(alignment: .leading, spacing: 0) {
            MenuBarPanelHeader(
                openAction: previewOpenAction,
                focusedTarget: $focusedTarget,
                perform: { _ in }
            )

            Divider()
                .opacity(0.22)

            MenuBarAssignmentSection(
                list: MenuBarAssignmentList(
                    physicalKeyboards: keyboards,
                    assignedInputSourceNames: Dictionary(
                        uniqueKeysWithValues: keyboards.map { keyboard in
                            (keyboard.id, "Italian")
                        }
                    )
                ),
                emphasis: chrome.assignmentEmphasis,
                focusedTarget: $focusedTarget
            )
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 10)

            MenuBarActionList(
                actions: previewActions,
                focusedTarget: $focusedTarget,
                perform: { _ in }
            )
        }
        .frame(width: MenuBarPanelLayout.panelWidth)
        .background(
            chrome.surface == .opaque
                ? Color(nsColor: .windowBackgroundColor)
                : Color.clear
        )
    }

    private var previewOpenAction: MenuBarPanelContent.Action {
        MenuBarPanelContent.Action(
            id: .openKeyameleon,
            title: "Open Keyameleon",
            isEnabled: true,
            closesPanel: true
        )
    }

    private var previewActions: [MenuBarPanelContent.Action] {
        [
            MenuBarPanelContent.Action(
                id: .pause,
                title: "Pause",
                isEnabled: true,
                closesPanel: false
            ),
            MenuBarPanelContent.Action(
                id: .settings,
                title: "Settings",
                isEnabled: true,
                closesPanel: true
            ),
            MenuBarPanelContent.Action(
                id: .quit,
                title: "Quit Keyameleon",
                isEnabled: true,
                closesPanel: true
            )
        ]
    }

    private func previewKeyboards() -> [PhysicalKeyboard] {
        if !names.isEmpty {
            return names.enumerated().map { index, name in
                previewKeyboard(name: name, identifier: "kb-\(index)", isActive: index == 0)
            }
        }
        if count == 0 {
            return []
        }
        return (1...count).map { index in
            previewKeyboard(
                name: "Board \(index)",
                identifier: "board-\(index)",
                isActive: index == 1
            )
        }
    }

    private func previewKeyboard(
        name: String,
        identifier: String,
        isActive: Bool
    ) -> PhysicalKeyboard {
        PhysicalKeyboard(
            id: PhysicalKeyboardRecordID(rawValue: identifier),
            productName: name,
            customName: nil,
            transport: .usb,
            isBuiltIn: false,
            assignmentState: .assigned(KeyboardAssignment(inputSourceIdentifier: "it")!),
            connectedServiceCount: 1,
            connectionState: .connected,
            isActive: isActive
        )
    }
}
#endif
