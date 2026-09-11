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
            settingsPane(selection.section) {
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
        _ section: KeyameleonSettingsSection,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(section.title)
                    .font(.largeTitle)
                    .accessibilityAddTraits(.isHeader)
                Text(section.subtitle)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 16)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

@MainActor
private struct KeyameleonGeneralSettingsPane: View {
    @ObservedObject var model: KeyameleonGeneralSettingsModel

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Launch Keyameleon at login", isOn: launchAtLoginBinding)
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
                Text("Startup")
            } footer: {
                Text("Starts Keyameleon when you log in.")
            }

            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Authorization")
                        Spacer()
                        Text(notificationAuthorizationName(model.notificationAuthorizationState))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Notification Authorization")
                    .accessibilityValue(
                        notificationAuthorizationName(model.notificationAuthorizationState)
                    )

                    Divider()

                    HStack {

                        Spacer()

                        if model.notificationAuthorizationState == .notDetermined {
                            Button("Enable Notifications") {
                                model.requestOperationalNotificationAuthorization()
                            }
                        }


                        Button("Open System Settings") {
                            model.openNotificationSettings()
                        }
                    }
                }
            } header: {
                Text("Operational Notifications")
            } footer: {
                Text(
                    "Optional alerts for revoked Input Monitoring permission or unavailable Keyboard Assignments. Keyameleon never requests sound or badge access."
                )
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

    private func notificationAuthorizationName(
        _ state: OperationalNotificationAuthorizationState
    ) -> String {
        switch state {
        case .unknown:
            "Checking"
        case .notDetermined:
            "Not requested"
        case .denied:
            "Denied"
        case .authorized:
            "Authorized"
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
        model: KeyameleonPreviewFixtures.general(notificationState: .notDetermined),
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
        model: KeyameleonPreviewFixtures.general(notificationState: .notDetermined)
    )
}

#Preview("General pane launch error") {
    KeyameleonGeneralSettingsPane(
        model: KeyameleonPreviewFixtures.general(
            launchAtLoginFailure: true,
            notificationState: .denied
        )
    )
    .preferredColorScheme(.dark)
}

#endif
