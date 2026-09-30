import Foundation
@preconcurrency import SwiftData

@MainActor
final class SwiftDataPersistenceSession {
    private var openingError: Error?
    private var context: ModelContext?
    private let openContainer: (() throws -> ModelContainer)?
    private let saveContext: (ModelContext) throws -> Void
    private let beforeFetch: () throws -> Void
    private var isInTransaction = false
    private var notifications: [() -> Void] = []

    init(
        modelContext: ModelContext,
        save: ((ModelContext) throws -> Void)? = nil,
        beforeFetch: @escaping () throws -> Void = {}
    ) {
        context = modelContext
        modelContext.autosaveEnabled = false
        openContainer = nil
        saveContext = save ?? { try $0.save() }
        self.beforeFetch = beforeFetch
    }

    init(openContainer: @escaping () throws -> ModelContainer) {
        self.openContainer = openContainer
        saveContext = { try $0.save() }
        beforeFetch = {}
    }

    func modelContext() throws -> ModelContext {
        if let context { return context }
        if let openingError { throw openingError }
        guard let openContainer else { throw CocoaError(.fileReadUnknown) }
        let container: ModelContainer
        do {
            container = try openContainer()
        } catch {
            openingError = error
            throw error
        }
        let opened = ModelContext(container)
        opened.autosaveEnabled = false
        context = opened
        return opened
    }

    func retryOpening() {
        openingError = nil
    }

    func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> [T] {
        try beforeFetch()
        return try modelContext().fetch(descriptor)
    }

    func transaction(_ operation: () throws -> Void) throws {
        if isInTransaction {
            try operation()
            return
        }
        isInTransaction = true
        do {
            try operation()
            let context = try modelContext()
            if context.hasChanges { try saveContext(context) }
            isInTransaction = false
            let committedNotifications = notifications
            notifications.removeAll()
            committedNotifications.forEach { $0() }
        } catch {
            context?.rollback()
            notifications.removeAll()
            isInTransaction = false
            throw error
        }
    }

    func didChange(_ notification: @escaping () -> Void = {}) {
        notifications.append(notification)
    }
}
