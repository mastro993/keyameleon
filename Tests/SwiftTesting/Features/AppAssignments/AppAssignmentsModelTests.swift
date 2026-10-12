import Foundation
import Testing
@testable import Keyameleon

private let us = EligibleInputSource(identifier: "com.example.us", name: "U.S.")
private let italian = EligibleInputSource(identifier: "com.example.italian", name: "Italian")
private let terminal = InstalledApp(
    bundleIdentifier: "com.apple.Terminal",
    name: "Terminal",
    url: URL(filePath: "/System/Applications/Utilities/Terminal.app")
)
private let keyameleon = InstalledApp(
    bundleIdentifier: "dev.fedemas.keyameleon",
    name: "Keyameleon",
    url: URL(filePath: "/Applications/Keyameleon.app")
)

@MainActor
private func makeModel(
    store: InMemoryAppAssignmentStore = InMemoryAppAssignmentStore(),
    current: String? = italian.identifier
) -> AppAssignmentsModel {
    AppAssignmentsModel(
        store: store,
        apps: InMemoryInstalledApps(
            installed: [terminal, keyameleon],
            running: [terminal.bundleIdentifier, keyameleon.bundleIdentifier]
        ),
        ownBundleIdentifier: keyameleon.bundleIdentifier,
        currentInputSourceIdentifier: { current }
    )
}

@Test("A new App Assignment starts with the current Input Source")
@MainActor
func addingAppPreselectsCurrentInputSource() {
    let store = InMemoryAppAssignmentStore()
    let model = makeModel(store: store)
    model.add(terminal, eligibleInputSources: [us, italian])

    #expect(store.allAppAssignments() == [
        AppAssignment(bundleIdentifier: terminal.bundleIdentifier, appName: "Terminal", inputSourceIdentifier: italian.identifier)
    ])
    #expect(model.addableRunningApps().isEmpty)
}

@Test("Keyameleon itself can never get an App Assignment")
@MainActor
func keyameleonCannotBeAdded() {
    let model = makeModel()
    #expect(model.addableRunningApps() == [terminal])

    model.add(keyameleon, eligibleInputSources: [us])
    #expect(model.rows.isEmpty)
}

@Test("An uninstalled app keeps its App Assignment and shows as not installed")
@MainActor
func uninstalledAppKeepsAssignment() {
    let removed = AppAssignment(bundleIdentifier: "com.example.removed", appName: "Removed", inputSourceIdentifier: us.identifier)
    let model = makeModel(store: InMemoryAppAssignmentStore([removed]))

    #expect(model.rows.map(\.assignment) == [removed])
    #expect(model.rows.first?.isInstalled == false)
}

@Test("Changing and removing an App Assignment saves immediately")
@MainActor
func changingAndRemovingSaves() throws {
    let store = InMemoryAppAssignmentStore()
    let model = makeModel(store: store)
    model.add(terminal, eligibleInputSources: [us, italian])
    let row = try #require(model.rows.first)

    model.setInputSource(us.identifier, for: row)
    #expect(store.allAppAssignments().first?.inputSourceIdentifier == us.identifier)

    model.remove(try #require(model.rows.first))
    #expect(store.allAppAssignments().isEmpty)
    #expect(model.rows.isEmpty)
}
