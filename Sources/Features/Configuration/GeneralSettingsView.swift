import AppKit
import SwiftUI

@MainActor
struct KeyameleonSettingsView: View {
    @ObservedObject private var model: KeyameleonGeneralSettingsModel
    private let setupModel: KeyameleonSetupModel
    private let aboutInfo: KeyameleonAboutInfo
    @Bindable private var selection: KeyameleonSettingsSelection

    init(
        model: KeyameleonGeneralSettingsModel,
        setupModel: KeyameleonSetupModel,
        selection: KeyameleonSettingsSelection,
        aboutInfo: KeyameleonAboutInfo = .current
    ) {
        _model = ObservedObject(wrappedValue: model)
        self.setupModel = setupModel
        self.aboutInfo = aboutInfo
        self.selection = selection
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection.section) {
                ForEach(KeyameleonSettingsSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            settingsPane {
                switch selection.section {
                case .general:
                    KeyameleonGeneralSettingsPane(model: model)
                case .keyboards:
                    KeyameleonKeyboardSettingsView(model: setupModel)
                case .about:
                    KeyameleonAboutView(model: model, info: aboutInfo)
                }
            }
        }
        .frame(minWidth: 720, minHeight: 540)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: model.refresh)
    }

    private func settingsPane<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

@MainActor
private struct KeyameleonGeneralSettingsPane: View {
    @ObservedObject var model: KeyameleonGeneralSettingsModel

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Launch at login", isOn: launchAtLoginBinding)
                        .toggleStyle(.switch)
                        .frame(maxWidth: .infinity)

                    if model.launchAtLoginError != nil {
                        Divider()
                        Text(
                            "Could not change Launch at Login. Open System Settings → General → Login Items if macOS requires approval."
                        )
                        .font(.callout)
                        .foregroundStyle(.red)
                    }
                }
            } header: {
                Text("App")
            }
        }
        .formStyle(.grouped)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.isLaunchAtLoginEnabled },
            set: { model.setLaunchAtLoginEnabled($0) }
        )
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
        model: KeyameleonPreviewFixtures.general(),
        setupModel: KeyameleonPreviewFixtures.setup(.assignmentsEmpty).model,
        aboutInfo: KeyameleonPreviewFixtures.aboutInfo
    )
}

#Preview("Settings keyboards") {
    KeyameleonSettingsPreviewHost(
        section: .keyboards,
        model: KeyameleonPreviewFixtures.general(),
        setupModel: KeyameleonPreviewFixtures.setup(.mixedAssignments).model,
        aboutInfo: KeyameleonPreviewFixtures.aboutInfo
    )
    .preferredColorScheme(.dark)
}

#Preview("Settings about") {
    KeyameleonSettingsPreviewHost(
        section: .about,
        model: KeyameleonPreviewFixtures.general(canCheckForUpdates: false),
        setupModel: KeyameleonPreviewFixtures.setup(.assignmentsEmpty).model,
        aboutInfo: KeyameleonPreviewFixtures.aboutInfo
    )
    .environment(\.dynamicTypeSize, .xxxLarge)
}

#Preview("General pane empty") {
    KeyameleonGeneralSettingsPane(
        model: KeyameleonPreviewFixtures.general()
    )
}

#Preview("General pane launch error") {
    KeyameleonGeneralSettingsPane(
        model: KeyameleonPreviewFixtures.general(launchAtLoginFailure: true)
    )
    .preferredColorScheme(.dark)
}

#endif
