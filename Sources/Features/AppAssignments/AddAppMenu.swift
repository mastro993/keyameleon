import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Adds an App Assignment: one running app, or any app chosen in an open panel.
@MainActor
struct AddAppMenu: View {
    let model: AppAssignmentsModel
    let eligibleInputSources: [EligibleInputSource]

    var body: some View {
        Menu {
            let runningApps = model.addableRunningApps()
            ForEach(runningApps) { app in
                Button {
                    model.add(app, eligibleInputSources: eligibleInputSources)
                } label: {
                    Label {
                        Text(app.name)
                    } icon: {
                        Image(nsImage: AppIconView.menuImage(for: app.url))
                    }
                }
            }
            if !runningApps.isEmpty {
                Divider()
            }
            Button(.chooseOtherAppEllipsis, action: chooseApp)
        } label: {
            Label(.addAppEllipsis, systemImage: "plus")
        }
        .fixedSize()
        .disabled(eligibleInputSources.isEmpty || model.hasPersistenceFailure)
        .accessibilityIdentifier("add-app")
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(filePath: "/Applications", directoryHint: .isDirectory)
        Task {
            guard await panel.begin() == .OK, let url = panel.url else { return }
            model.addApp(at: url, eligibleInputSources: eligibleInputSources)
        }
    }
}

#if DEBUG
#Preview("Add app menu") {
    AddAppMenu(model: PreviewFixtures.appAssignments(), eligibleInputSources: PreviewFixtures.inputSources())
        .padding()
}
#endif
