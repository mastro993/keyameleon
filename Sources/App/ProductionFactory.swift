import Foundation

/// The application composition root for Activity-Triggered Switching.
///
/// This factory builds the shared internal modules once so SetupModel and
/// Activity-Triggered Switching use the same discovery, Input Source, and
/// Operational Notification state.
@MainActor
struct KeyameleonActivityTriggeredSwitchingComposition {
    let physicalKeyboardDiscovery: PhysicalKeyboardDiscovery
    let inputSources: InputSourceModule
    let operationalNotifications: OperationalNotifications
    let activityTriggeredSwitching: ActivityTriggeredSwitching
    let setupStore: any SetupDecisionStoring
    let physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring
    let designationStore: any ManualPhysicalKeyboardDesignationStoring
    let integrityKeyProvider: any InstallationIntegrityKeyProviding
    let diagnosticDataController: any DiagnosticDataControlling
}

@MainActor
enum KeyameleonProductionFactory {
    /// Builds the live application composition. Persistence adapters are passed
    /// in because the application owns their model containers.
    static func makeLiveComposition(
        setupStore: any SetupDecisionStoring,
        physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring,
        designationStore: any ManualPhysicalKeyboardDesignationStoring,
        integrityKeyProvider: any InstallationIntegrityKeyProviding,
        diagnosticDataController: any DiagnosticDataControlling,
        operationalNotificationProvider: any OperationalNotificationProviding,
        notificationEpisodeStore: any OperationalNotificationEpisodeStoring,
        notificationSetupStore: any NotificationSetupDecisionStoring
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
            integrityKeyProvider: integrityKeyProvider,
            diagnosticDataController: diagnosticDataController,
            operationalNotificationProvider: operationalNotificationProvider,
            notificationEpisodeStore: notificationEpisodeStore,
            notificationSetupStore: notificationSetupStore
        )
    }

    static func makeActivityTriggeredSwitching(
        permissionProvider: any ListenPermissionProviding = SystemListenPermissionProvider(),
        protectedStateProvider: any ProtectedStateProviding = SystemProtectedStateProvider(),
        setupStore: any SetupDecisionStoring = UserDefaultsSetupDecisionStore(),
        physicalKeyboardDiscoverer: any PhysicalKeyboardDiscovering =
            SystemPhysicalKeyboardDiscoverer(),
        physicalKeyboardEventObserver: any PhysicalKeyboardEventObserving =
            SystemPhysicalKeyboardEventObserver(),
        inputSourceProvider: any InputSourceProviding = SystemInputSourceProvider(),
        inputSourceSelector: any InputSourceSelecting = SystemInputSourceProvider(),
        inputSourceChangeObserver: any InputSourceChangeObserving =
            SystemInputSourceChangeObserver(),
        physicalKeyboardRecordStore: any PhysicalKeyboardRecordStoring =
            InMemoryPhysicalKeyboardRecordStore(),
        designationStore: any ManualPhysicalKeyboardDesignationStoring =
            InMemoryManualPhysicalKeyboardDesignationStore(),
        integrityKeyProvider: any InstallationIntegrityKeyProviding =
            InMemoryInstallationIntegrityKeyProvider(),
        diagnosticDataController: any DiagnosticDataControlling = KeyameleonDiagnosticDataService(
            store: InMemoryDiagnosticDataStore()
        ),
        operationalNotificationProvider: any OperationalNotificationProviding =
            NoOpOperationalNotificationProvider(),
        notificationEpisodeStore: any OperationalNotificationEpisodeStoring =
            InMemoryOperationalNotificationEpisodeStore(),
        notificationSetupStore: any NotificationSetupDecisionStoring =
            InMemoryNotificationSetupDecisionStore()
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
        let operationalNotifications = OperationalNotifications(
            provider: operationalNotificationProvider,
            episodeStore: notificationEpisodeStore,
            setupStore: notificationSetupStore
        )
        let activityTriggeredSwitching = ActivityTriggeredSwitching(
            permissionProvider: permissionProvider,
            protectedStateProvider: protectedStateProvider,
            setupStore: setupStore,
            physicalKeyboardDiscovery: physicalKeyboardDiscovery,
            inputSources: inputSources,
            physicalKeyboardRecordStore: physicalKeyboardRecordStore,
            designationStore: designationStore,
            integrityKeyProvider: integrityKeyProvider,
            diagnosticDataController: diagnosticDataController,
            operationalNotifications: operationalNotifications
        )

        return KeyameleonActivityTriggeredSwitchingComposition(
            physicalKeyboardDiscovery: physicalKeyboardDiscovery,
            inputSources: inputSources,
            operationalNotifications: operationalNotifications,
            activityTriggeredSwitching: activityTriggeredSwitching,
            setupStore: setupStore,
            physicalKeyboardRecordStore: physicalKeyboardRecordStore,
            designationStore: designationStore,
            integrityKeyProvider: integrityKeyProvider,
            diagnosticDataController: diagnosticDataController
        )
    }
}
