import AppKit
import SwiftUI

/// The Settings window: a fixed navigation sidebar beside the selected pane.
@MainActor
struct KeyameleonSettingsView: View {
    private let model: KeyameleonGeneralSettingsModel
    private let setupModel: KeyameleonSetupModel
    private let selection: KeyameleonSettingsSelection
    private let aboutInfo: KeyameleonAboutInfo

    init(
        model: KeyameleonGeneralSettingsModel,
        setupModel: KeyameleonSetupModel,
        selection: KeyameleonSettingsSelection,
        aboutInfo: KeyameleonAboutInfo = .current
    ) {
        self.model = model
        self.setupModel = setupModel
        self.selection = selection
        self.aboutInfo = aboutInfo
    }

    var body: some View {
        HStack(spacing: 0) {
            KeyameleonSettingsSidebar(selection: selection)
            VStack(spacing: 0) {
                PersistenceFailureNotice(model: setupModel)
                pane
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(KeyameleonTheme.contentBackground, ignoresSafeAreaEdges: .all)
        }
        .frame(minWidth: KeyameleonTheme.Metrics.settingsWindowMinimumWidth)
        .onAppear(perform: model.refresh)
    }

    @ViewBuilder
    private var pane: some View {
        switch selection.section {
        case .general:
            KeyameleonGeneralSettingsPane(model: model)
        case .keyboards:
            KeyameleonKeyboardSettingsPane(model: setupModel)
        case .about:
            KeyameleonAboutSettingsPane(model: model, info: aboutInfo)
        }
    }
}

#if DEBUG
@MainActor
private struct KeyameleonSettingsPreviewHost: View {
    let model: KeyameleonGeneralSettingsModel
    let setupModel: KeyameleonSetupModel
    let aboutInfo: KeyameleonAboutInfo
    @State private var selection: KeyameleonSettingsSelection

    init(
        section: KeyameleonSettingsSection,
        model: KeyameleonGeneralSettingsModel,
        setupModel: KeyameleonSetupModel,
        aboutInfo: KeyameleonAboutInfo
    ) {
        self.model = model
        self.setupModel = setupModel
        self.aboutInfo = aboutInfo
        let selection = KeyameleonSettingsSelection()
        selection.section = section
        _selection = State(initialValue: selection)
    }

    var body: some View {
        KeyameleonSettingsView(
            model: model,
            setupModel: setupModel,
            selection: selection,
            aboutInfo: aboutInfo
        )
    }
}

#Preview("Settings general") {
    KeyameleonSettingsPreviewHost(
        section: .general,
        model: KeyameleonPreviewFixtures.general(launchAtLoginEnabled: true),
        setupModel: KeyameleonPreviewFixtures.setup(.pencilAssignments).model,
        aboutInfo: KeyameleonPreviewFixtures.aboutInfo
    )
}

#Preview("Settings keyboards") {
    KeyameleonSettingsPreviewHost(
        section: .keyboards,
        model: KeyameleonPreviewFixtures.general(),
        setupModel: KeyameleonPreviewFixtures.setup(.pencilAssignments).model,
        aboutInfo: KeyameleonPreviewFixtures.aboutInfo
    )
}

#Preview("Settings keyboards dark") {
    KeyameleonSettingsPreviewHost(
        section: .keyboards,
        model: KeyameleonPreviewFixtures.general(),
        setupModel: KeyameleonPreviewFixtures.setup(.pencilAssignments).model,
        aboutInfo: KeyameleonPreviewFixtures.aboutInfo
    )
    .preferredColorScheme(.dark)
}

#Preview("Settings keyboards empty") {
    KeyameleonSettingsPreviewHost(
        section: .keyboards,
        model: KeyameleonPreviewFixtures.general(),
        setupModel: KeyameleonPreviewFixtures.setup(.assignmentsEmpty).model,
        aboutInfo: KeyameleonPreviewFixtures.aboutInfo
    )
}

#Preview("Settings keyboards large text") {
    KeyameleonSettingsPreviewHost(
        section: .keyboards,
        model: KeyameleonPreviewFixtures.general(),
        setupModel: KeyameleonPreviewFixtures.setup(.manyAssignments).model,
        aboutInfo: KeyameleonPreviewFixtures.aboutInfo
    )
    .environment(\.dynamicTypeSize, .xxxLarge)
}

#Preview("Settings about") {
    KeyameleonSettingsPreviewHost(
        section: .about,
        model: KeyameleonPreviewFixtures.general(canCheckForUpdates: false),
        setupModel: KeyameleonPreviewFixtures.setup(.assignmentsEmpty).model,
        aboutInfo: KeyameleonPreviewFixtures.aboutInfo
    )
    .preferredColorScheme(.dark)
}
#endif
