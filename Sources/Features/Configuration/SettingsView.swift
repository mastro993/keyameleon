import AppKit
import SwiftUI

/// The Settings window: a fixed navigation sidebar beside the selected pane.
@MainActor
struct SettingsView: View {
    private let model: GeneralSettingsModel
    private let setupModel: SetupModel
    private let selection: SettingsSelection
    private let aboutInfo: AboutInfo

    init(
        model: GeneralSettingsModel,
        setupModel: SetupModel,
        selection: SettingsSelection,
        aboutInfo: AboutInfo = .current
    ) {
        self.model = model
        self.setupModel = setupModel
        self.selection = selection
        self.aboutInfo = aboutInfo
    }

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: selection)
            VStack(spacing: 0) {
                PersistenceFailureNotice(model: setupModel)
                pane
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // The pane fills under the transparent title bar and supplies its own top inset.
            .ignoresSafeArea(edges: .top)
            .background(Theme.contentBackground, ignoresSafeAreaEdges: .all)
        }
        .frame(
            minWidth: Theme.Metrics.settingsWindowMinimumWidth,
            minHeight: Theme.Metrics.settingsWindowMinimumHeight
        )
        .onAppear(perform: model.refresh)
    }

    @ViewBuilder
    private var pane: some View {
        switch selection.section {
        case .general:
            GeneralSettingsPane(model: model)
        case .keyboards:
            KeyboardSettingsPane(model: setupModel)
        case .about:
            AboutSettingsPane(model: model, info: aboutInfo)
        }
    }
}

#if DEBUG
@MainActor
private struct SettingsPreviewHost: View {
    let model: GeneralSettingsModel
    let setupModel: SetupModel
    let aboutInfo: AboutInfo
    @State private var selection: SettingsSelection

    init(
        section: SettingsSection,
        model: GeneralSettingsModel,
        setupModel: SetupModel,
        aboutInfo: AboutInfo
    ) {
        self.model = model
        self.setupModel = setupModel
        self.aboutInfo = aboutInfo
        let selection = SettingsSelection()
        selection.section = section
        _selection = State(initialValue: selection)
    }

    var body: some View {
        SettingsView(
            model: model,
            setupModel: setupModel,
            selection: selection,
            aboutInfo: aboutInfo
        )
    }
}

#Preview("Settings general") {
    SettingsPreviewHost(
        section: .general,
        model: PreviewFixtures.general(launchAtLoginEnabled: true),
        setupModel: PreviewFixtures.setup(.pencilAssignments).model,
        aboutInfo: PreviewFixtures.aboutInfo
    )
}

#Preview("Settings keyboards") {
    SettingsPreviewHost(
        section: .keyboards,
        model: PreviewFixtures.general(),
        setupModel: PreviewFixtures.setup(.pencilAssignments).model,
        aboutInfo: PreviewFixtures.aboutInfo
    )
}

#Preview("Settings keyboards dark") {
    SettingsPreviewHost(
        section: .keyboards,
        model: PreviewFixtures.general(),
        setupModel: PreviewFixtures.setup(.pencilAssignments).model,
        aboutInfo: PreviewFixtures.aboutInfo
    )
    .preferredColorScheme(.dark)
}

#Preview("Settings keyboards empty") {
    SettingsPreviewHost(
        section: .keyboards,
        model: PreviewFixtures.general(),
        setupModel: PreviewFixtures.setup(.assignmentsEmpty).model,
        aboutInfo: PreviewFixtures.aboutInfo
    )
}

#Preview("Settings keyboards large text") {
    SettingsPreviewHost(
        section: .keyboards,
        model: PreviewFixtures.general(),
        setupModel: PreviewFixtures.setup(.manyAssignments).model,
        aboutInfo: PreviewFixtures.aboutInfo
    )
    .environment(\.dynamicTypeSize, .xxxLarge)
}

#Preview("Settings about") {
    SettingsPreviewHost(
        section: .about,
        model: PreviewFixtures.general(canCheckForUpdates: false),
        setupModel: PreviewFixtures.setup(.assignmentsEmpty).model,
        aboutInfo: PreviewFixtures.aboutInfo
    )
    .preferredColorScheme(.dark)
}
#endif
