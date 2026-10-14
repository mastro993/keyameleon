import Foundation

/// The application composition root for Activity-Triggered Switching.
///
/// This factory builds the shared internal modules once so SetupModel and
/// Activity-Triggered Switching use the same discovery and Input Source.
@MainActor
struct ActivityTriggeredSwitchingComposition {
    let permissionProvider: any ListenPermissionProviding
    let physicalKeyboardDiscovery: PhysicalKeyboardDiscovery
    let inputSources: InputSourceModule
    let activityTriggeredSwitching: ActivityTriggeredSwitching
    let setupStore: any SetupDecisionStoring
    let physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring
    let designationStore: any ManualPhysicalKeyboardDesignationStoring
    let savedPhysicalKeyboardChanges: SavedPhysicalKeyboardChanges
    let exclusionStore: any PhysicalKeyboardExclusionStoring
    let integrityKeyProvider: any InstallationIntegrityKeyProviding
    let appAssignmentStore: any AppAssignmentStoring
}

@MainActor
enum ProductionFactory {
    /// Builds the live application composition. The persistence session is
    /// passed in because the application owns its model container; saved
    /// records, designations, and App Assignments share it.
    static func makeLiveComposition(
        setupStore: any SetupDecisionStoring,
        persistenceSession: SwiftDataPersistenceSession,
        exclusionStore: any PhysicalKeyboardExclusionStoring,
        integrityKeyProvider: any InstallationIntegrityKeyProviding
    ) -> ActivityTriggeredSwitchingComposition {
        let inputSources = SystemInputSourceProvider()
        return makeActivityTriggeredSwitching(
            permissionProvider: SystemListenPermissionProvider(),
            protectedStateProvider: SystemProtectedStateProvider(),
            setupStore: setupStore,
            physicalKeyboardDiscoverer: SystemPhysicalKeyboardDiscoverer(),
            physicalKeyboardEventObserver: SystemPhysicalKeyboardEventObserver(),
            inputSourceProvider: inputSources,
            inputSourceSelector: inputSources,
            inputSourceChangeObserver: SystemInputSourceChangeObserver(),
            physicalKeyboardRecordStore: SwiftDataPhysicalKeyboardRecordStore(session: persistenceSession),
            designationStore: SwiftDataManualPhysicalKeyboardDesignationStore(session: persistenceSession),
            exclusionStore: exclusionStore,
            integrityKeyProvider: integrityKeyProvider,
            appAssignmentStore: SwiftDataAppAssignmentStore(session: persistenceSession),
            frontmostAppObserver: SystemFrontmostAppObserver()
        )
    }

    static func makeActivityTriggeredSwitching(
        permissionProvider: any ListenPermissionProviding = SystemListenPermissionProvider(),
        protectedStateProvider: any ProtectedStateProviding = SystemProtectedStateProvider(),
        setupStore: any SetupDecisionStoring = UserDefaultsSetupDecisionStore(),
        physicalKeyboardDiscoverer: any PhysicalKeyboardDiscovering =
            NoOpPhysicalKeyboardDiscoverer(),
        physicalKeyboardEventObserver: any PhysicalKeyboardEventObserving =
            NoOpPhysicalKeyboardEventObserver(),
        inputSourceProvider: any InputSourceProviding = NoOpInputSourceProvider(),
        inputSourceSelector: any InputSourceSelecting = NoOpInputSourceSelector(),
        inputSourceChangeObserver: any InputSourceChangeObserving =
            NoOpInputSourceChangeObserver(),
        physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring =
            InMemoryPhysicalKeyboardRecordStore(),
        designationStore: any ManualPhysicalKeyboardDesignationStoring =
            InMemoryManualPhysicalKeyboardDesignationStore(),
        exclusionStore: any PhysicalKeyboardExclusionStoring =
            InMemoryPhysicalKeyboardExclusionStore(),
        integrityKeyProvider: any InstallationIntegrityKeyProviding =
            InMemoryInstallationIntegrityKeyProvider(),
        appAssignmentStore: any AppAssignmentStoring = InMemoryAppAssignmentStore(),
        frontmostAppObserver: any FrontmostAppObserving = NoOpFrontmostAppObserver()
    ) -> ActivityTriggeredSwitchingComposition {
        let savedPhysicalKeyboardChanges: SavedPhysicalKeyboardChanges
        if let records = physicalKeyboardRecordStore as? SwiftDataPhysicalKeyboardRecordStore {
            savedPhysicalKeyboardChanges = SavedPhysicalKeyboardChanges(records: records)
        } else if let records = physicalKeyboardRecordStore as? InMemoryPhysicalKeyboardRecordStore {
            savedPhysicalKeyboardChanges = SavedPhysicalKeyboardChanges(records: records)
        } else {
            preconditionFailure("Saved Physical Keyboard changes require a SwiftData or in-memory record store")
        }

        let physicalKeyboardDiscovery = PhysicalKeyboardDiscovery(
            discoverer: physicalKeyboardDiscoverer,
            eventObserver: physicalKeyboardEventObserver
        )
        let inputSources = InputSourceModule(
            provider: inputSourceProvider,
            selector: inputSourceSelector,
            changeObserver: inputSourceChangeObserver
        )
        let activityTriggeredSwitching = ActivityTriggeredSwitching(
            permissionProvider: permissionProvider,
            protectedStateProvider: protectedStateProvider,
            setupStore: setupStore,
            physicalKeyboardDiscovery: physicalKeyboardDiscovery,
            inputSources: inputSources,
            physicalKeyboardRecordStore: physicalKeyboardRecordStore,
            designationStore: designationStore,
            exclusionStore: exclusionStore,
            integrityKeyProvider: integrityKeyProvider,
            appAssignmentStore: appAssignmentStore,
            frontmostAppObserver: frontmostAppObserver
        )

        return ActivityTriggeredSwitchingComposition(
            permissionProvider: permissionProvider,
            physicalKeyboardDiscovery: physicalKeyboardDiscovery,
            inputSources: inputSources,
            activityTriggeredSwitching: activityTriggeredSwitching,
            setupStore: setupStore,
            physicalKeyboardRecordStore: physicalKeyboardRecordStore,
            designationStore: designationStore,
            savedPhysicalKeyboardChanges: savedPhysicalKeyboardChanges,
            exclusionStore: exclusionStore,
            integrityKeyProvider: integrityKeyProvider,
            appAssignmentStore: appAssignmentStore
        )
    }
}
