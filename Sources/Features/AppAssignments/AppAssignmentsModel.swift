import Foundation
import Observation

/// Adds, edits, and removes App Assignments for the Apps pane.
///
/// Activity-Triggered Switching observes the store, so a saved change reaches
/// switching without this model telling it.
@MainActor
@Observable
final class AppAssignmentsModel {
    private(set) var rows: [AppAssignmentRow] = []
    private(set) var hasPersistenceFailure = false

    private let store: any AppAssignmentStoring
    private let apps: any InstalledAppsProviding
    private let ownBundleIdentifier: String?
    private let currentInputSourceIdentifier: @MainActor () -> String?

    init(
        store: any AppAssignmentStoring,
        apps: any InstalledAppsProviding = SystemInstalledApps(),
        ownBundleIdentifier: String? = Bundle.main.bundleIdentifier,
        currentInputSourceIdentifier: @escaping @MainActor () -> String? = { nil }
    ) {
        self.store = store
        self.apps = apps
        self.ownBundleIdentifier = ownBundleIdentifier
        self.currentInputSourceIdentifier = currentInputSourceIdentifier
        refresh()
    }

    func refresh() {
        do {
            rows = try store.allAppAssignments().map {
                AppAssignmentRow(assignment: $0, appURL: apps.url(forBundleIdentifier: $0.bundleIdentifier))
            }
            hasPersistenceFailure = false
        } catch {
            markPersistenceFailure()
        }
    }

    /// Running apps without an App Assignment, by name. Keyameleon is never one.
    func addableRunningApps() -> [InstalledApp] {
        apps.runningApps()
            .filter(canAdd)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Adds the app with the current Input Source, or the first eligible one.
    func add(_ app: InstalledApp, eligibleInputSources: [EligibleInputSource]) {
        guard canAdd(app) else { return }
        let current = currentInputSourceIdentifier()
        let inputSource = eligibleInputSources.first { $0.identifier == current } ?? eligibleInputSources.first
        guard let inputSource else { return }
        save(AppAssignment(
            bundleIdentifier: app.bundleIdentifier,
            appName: app.name,
            inputSourceIdentifier: inputSource.identifier
        ))
    }

    func addApp(at url: URL, eligibleInputSources: [EligibleInputSource]) {
        guard let app = apps.app(at: url) else { return }
        add(app, eligibleInputSources: eligibleInputSources)
    }

    func setInputSource(_ inputSourceIdentifier: String, for row: AppAssignmentRow) {
        guard inputSourceIdentifier != row.assignment.inputSourceIdentifier else { return }
        save(AppAssignment(
            bundleIdentifier: row.assignment.bundleIdentifier,
            appName: row.assignment.appName,
            inputSourceIdentifier: inputSourceIdentifier
        ))
    }

    func remove(_ row: AppAssignmentRow) {
        do {
            try store.deleteAppAssignment(bundleIdentifier: row.id)
            Log.debug(.setup, "Removed the App Assignment for \(row.assignment.appName)")
            refresh()
        } catch {
            markPersistenceFailure()
        }
    }

    private func canAdd(_ app: InstalledApp) -> Bool {
        app.bundleIdentifier != ownBundleIdentifier && !rows.contains { $0.id == app.bundleIdentifier }
    }

    private func save(_ assignment: AppAssignment) {
        do {
            try store.saveAppAssignment(assignment)
            Log.debug(
                .setup,
                "App Assignment for \(assignment.appName) is now \(assignment.inputSourceIdentifier)"
            )
            refresh()
        } catch {
            markPersistenceFailure()
        }
    }

    private func markPersistenceFailure() {
        Log.error(.setup, "Saved App Assignments could not be read or changed")
        hasPersistenceFailure = true
    }
}
