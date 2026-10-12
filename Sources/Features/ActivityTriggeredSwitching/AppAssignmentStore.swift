import Foundation
@preconcurrency import SwiftData

@MainActor
protocol AppAssignmentStoring: AnyObject {
    /// Every App Assignment, ordered by app name.
    func allAppAssignments() throws -> [AppAssignment]
    func appAssignment(forBundleIdentifier bundleIdentifier: String) throws -> AppAssignment?
    /// Adds the App Assignment or replaces the one for the same app.
    func saveAppAssignment(_ assignment: AppAssignment) throws
    func deleteAppAssignment(bundleIdentifier: String) throws
    func startObservingChanges(onChange: @escaping @MainActor () -> Void)
    func stopObservingChanges()
}

extension AppAssignmentStoring {
    func appAssignment(forBundleIdentifier bundleIdentifier: String) throws -> AppAssignment? {
        try allAppAssignments().first { $0.bundleIdentifier == bundleIdentifier }
    }
}

/// The store's schema. Version 2 adds App Assignments to the saved Physical
/// Keyboard records and designations of version 1.
enum PhysicalKeyboardSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(2, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [
            PhysicalKeyboardSchemaV1.PhysicalKeyboardRecordModel.self,
            ManualPhysicalKeyboardDesignationSchemaV1.ManualPhysicalKeyboardDesignationModel.self,
            AppAssignmentModel.self
        ]
    }

    @Model
    final class AppAssignmentModel {
        @Attribute(.unique) var bundleIdentifier: String
        var appName: String
        var inputSourceIdentifier: String

        init(bundleIdentifier: String, appName: String, inputSourceIdentifier: String) {
            self.bundleIdentifier = bundleIdentifier
            self.appName = appName
            self.inputSourceIdentifier = inputSourceIdentifier
        }

        var appAssignment: AppAssignment {
            AppAssignment(
                bundleIdentifier: bundleIdentifier,
                appName: appName,
                inputSourceIdentifier: inputSourceIdentifier
            )
        }
    }
}

@MainActor
final class SwiftDataAppAssignmentStore: AppAssignmentStoring {
    private let session: SwiftDataPersistenceSession
    private var onChange: (@MainActor () -> Void)?

    init(session: SwiftDataPersistenceSession) {
        self.session = session
    }

    func allAppAssignments() throws -> [AppAssignment] {
        try session.fetch(FetchDescriptor<PhysicalKeyboardSchemaV2.AppAssignmentModel>())
            .map(\.appAssignment)
            .sorted { $0.appName.localizedStandardCompare($1.appName) == .orderedAscending }
    }

    func saveAppAssignment(_ assignment: AppAssignment) throws {
        try session.transaction {
            if let existing = try fetchModel(bundleIdentifier: assignment.bundleIdentifier) {
                existing.appName = assignment.appName
                existing.inputSourceIdentifier = assignment.inputSourceIdentifier
            } else {
                try session.modelContext().insert(PhysicalKeyboardSchemaV2.AppAssignmentModel(
                    bundleIdentifier: assignment.bundleIdentifier,
                    appName: assignment.appName,
                    inputSourceIdentifier: assignment.inputSourceIdentifier
                ))
            }
            session.didChange { [weak self] in self?.onChange?() }
        }
    }

    func deleteAppAssignment(bundleIdentifier: String) throws {
        try session.transaction {
            guard let model = try fetchModel(bundleIdentifier: bundleIdentifier) else { return }
            try session.modelContext().delete(model)
            session.didChange { [weak self] in self?.onChange?() }
        }
    }

    func startObservingChanges(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
    }

    func stopObservingChanges() {
        onChange = nil
    }

    private func fetchModel(bundleIdentifier: String) throws -> PhysicalKeyboardSchemaV2.AppAssignmentModel? {
        var descriptor = FetchDescriptor<PhysicalKeyboardSchemaV2.AppAssignmentModel>(
            predicate: #Predicate { $0.bundleIdentifier == bundleIdentifier }
        )
        descriptor.fetchLimit = 1
        return try session.fetch(descriptor).first
    }
}

@MainActor
final class InMemoryAppAssignmentStore: AppAssignmentStoring {
    private var assignments: [String: AppAssignment]
    private var onChange: (@MainActor () -> Void)?

    init(_ assignments: [AppAssignment] = []) {
        self.assignments = Dictionary(uniqueKeysWithValues: assignments.map { ($0.bundleIdentifier, $0) })
    }

    func allAppAssignments() -> [AppAssignment] {
        assignments.values.sorted { $0.appName.localizedStandardCompare($1.appName) == .orderedAscending }
    }

    func saveAppAssignment(_ assignment: AppAssignment) {
        assignments[assignment.bundleIdentifier] = assignment
        onChange?()
    }

    func deleteAppAssignment(bundleIdentifier: String) {
        guard assignments.removeValue(forKey: bundleIdentifier) != nil else { return }
        onChange?()
    }

    func startObservingChanges(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
    }

    func stopObservingChanges() {
        onChange = nil
    }
}
