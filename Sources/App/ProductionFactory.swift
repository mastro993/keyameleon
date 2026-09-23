import Foundation

/// The application composition root for Activity-Triggered Switching.
///
/// This factory builds the shared internal modules once so SetupModel and
/// Activity-Triggered Switching use the same discovery and Input Source.
@MainActor
struct KeyameleonActivityTriggeredSwitchingComposition {
    let physicalKeyboardDiscovery: PhysicalKeyboardDiscovery
    let inputSources: InputSourceModule
    let activityTriggeredSwitching: ActivityTriggeredSwitching
    let setupStore: any SetupDecisionStoring
    let physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring
    let designationStore: any ManualPhysicalKeyboardDesignationStoring
    let integrityKeyProvider: any InstallationIntegrityKeyProviding
}

@MainActor
enum KeyameleonProductionFactory {
    /// Builds the live application composition. Persistence adapters are passed
    /// in because the application owns their model containers.
    static func makeLiveComposition(
        setupStore: any SetupDecisionStoring,
        physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring,
        designationStore: any ManualPhysicalKeyboardDesignationStoring,
        integrityKeyProvider: any InstallationIntegrityKeyProviding
    ) -> KeyameleonActivityTriggeredSwitchingComposition {
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
            physicalKeyboardRecordStore: physicalKeyboardRecordStore,
            designationStore: designationStore,
            integrityKeyProvider: integrityKeyProvider
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
        integrityKeyProvider: any InstallationIntegrityKeyProviding =
            InMemoryInstallationIntegrityKeyProvider()
    ) -> KeyameleonActivityTriggeredSwitchingComposition {
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
            integrityKeyProvider: integrityKeyProvider
        )

        return KeyameleonActivityTriggeredSwitchingComposition(
            physicalKeyboardDiscovery: physicalKeyboardDiscovery,
            inputSources: inputSources,
            activityTriggeredSwitching: activityTriggeredSwitching,
            setupStore: setupStore,
            physicalKeyboardRecordStore: physicalKeyboardRecordStore,
            designationStore: designationStore,
            integrityKeyProvider: integrityKeyProvider
        )
    }
}
