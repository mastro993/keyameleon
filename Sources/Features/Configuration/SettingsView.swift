import SwiftUI

/// The Settings content: the selected pane under any persistence failure notice.
/// `SettingsWindowController` supplies the toolbar that changes the selection.
@MainActor
struct SettingsView: View {
    private let model: GeneralSettingsModel
    private let setupModel: SetupModel
    private let appAssignmentsModel: AppAssignmentsModel
    private let selection: SettingsSelection
    private let aboutInfo: AboutInfo

    init(
        model: GeneralSettingsModel,
        setupModel: SetupModel,
        appAssignmentsModel: AppAssignmentsModel,
        selection: SettingsSelection,
        aboutInfo: AboutInfo = .current
    ) {
        self.model = model
        self.setupModel = setupModel
        self.appAssignmentsModel = appAssignmentsModel
        self.selection = selection
        self.aboutInfo = aboutInfo
    }

    var body: some View {
        VStack(spacing: 0) {
            PersistenceFailureNotice(model: setupModel)
            pane
        }
        .frame(
            minWidth: Theme.Metrics.settingsWindowMinimumWidth,
            maxWidth: .infinity,
            minHeight: Theme.Metrics.settingsWindowMinimumHeight,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(Theme.contentBackground)
        .onAppear(perform: model.refresh)
    }

    @ViewBuilder
    private var pane: some View {
        switch selection.section {
        case .general:
            GeneralSettingsPane(model: model)
        case .keyboards:
            KeyboardSettingsPane(model: setupModel)
        case .apps:
            AppSettingsPane(model: appAssignmentsModel, eligibleInputSources: setupModel.eligibleInputSources)
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
            appAssignmentsModel: PreviewFixtures.appAssignments(),
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

#Preview("Settings apps") {
    SettingsPreviewHost(
        section: .apps,
        model: PreviewFixtures.general(),
        setupModel: PreviewFixtures.setup(.pencilAssignments).model,
        aboutInfo: PreviewFixtures.aboutInfo
    )
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
