import CoreHID
import Foundation

@MainActor
protocol PhysicalKeyboardDiscovering: AnyObject {
    func start(onChange: @escaping @MainActor (PhysicalKeyboardDiscoveryChange) -> Void)
    func stop()
}

/// Test double / no-op default when discovery is not started.
@MainActor
final class NoOpPhysicalKeyboardDiscoverer: PhysicalKeyboardDiscovering {
    func start(onChange: @escaping @MainActor (PhysicalKeyboardDiscoveryChange) -> Void) {}
    func stop() {}
}

@MainActor
final class SystemPhysicalKeyboardDiscoverer: PhysicalKeyboardDiscovering {
    private var task: Task<Void, Never>?

    func start(onChange: @escaping @MainActor (PhysicalKeyboardDiscoveryChange) -> Void) {
        stop()

        task = Task { @MainActor in
            let manager = HIDDeviceManager()
            let criteria = HIDDeviceManager.DeviceMatchingCriteria(
                primaryUsage: .genericDesktop(.keyboard)
            )

            do {
                for try await notification in await manager.monitorNotifications(
                    matchingCriteria: [criteria]
                ) {
                    guard !Task.isCancelled else {
                        return
                    }

                    switch notification {
                    case let .deviceMatched(reference):
                        guard let facts = await Self.hardwareFacts(for: reference) else {
                            continue
                        }

                        onChange(.connected(facts))
                    case let .deviceRemoved(reference):
                        onChange(.disconnected(serviceID: reference.deviceID))
                    @unknown default:
                        continue
                    }
                }
            } catch {
                // Discovery is fail-closed. A later permission or lifecycle refresh restarts it.
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private static func hardwareFacts(
        for reference: HIDDeviceClient.DeviceReference
    ) async -> PhysicalKeyboardHardwareFacts? {
        guard let client = HIDDeviceClient(deviceReference: reference) else {
            return nil
        }

        guard await PhysicalKeyboardHIDInspection.recognition(for: client)
            .isPhysicalKeyboard
        else {
            return nil
        }

        // CoreHID's unique ID is software-based. Serial number or BLE address
        // is required before the identity can make a Physical Keyboard assignable.
        let isBuiltIn = await client.isBuiltIn
        let serialNumber = await client.serialNumber
        let bluetoothAddress = await PhysicalKeyboardHIDInspection.bluetoothAddress(
            for: client
        )
        let identity = await client.uniqueID.flatMap {
            PhysicalKeyboardIdentity(
                rawValue: $0,
                isBuiltIn: isBuiltIn,
                serialNumber: serialNumber,
                bluetoothAddress: bluetoothAddress
            )
        }

        return PhysicalKeyboardHardwareFacts(
            serviceID: reference.deviceID,
            identity: identity,
            name: await client.product,
            transport: transport(for: await client.transport),
            isBuiltIn: isBuiltIn,
            vendorID: await client.vendorID,
            productID: await client.productID,
            modelNumber: await client.modelNumber,
            serialNumber: serialNumber
        )
    }

    private static func transport(for transport: HIDDeviceTransport?) -> PhysicalKeyboardTransport {
        switch transport {
        case .usb:
            .usb
        case .bluetooth, .bluetoothAACP:
            .bluetooth
        case .bluetoothLowEnergy:
            .bluetoothLowEnergy
        default:
            .other
        }
    }
}

enum PhysicalKeyboardHIDInspection {
    static func recognition(for client: HIDDeviceClient) async -> PhysicalKeyboardHIDRecognition {
        let primaryUsage = await client.primaryUsage
        let deviceUsages = await client.deviceUsages
        let usages = [primaryUsage] + deviceUsages

        return PhysicalKeyboardHIDRecognition(
            hasKeyboardUsage: usages.contains { isKeyboardUsage($0) },
            hasMouseUsage: usages.contains { isMouseUsage($0) },
            hasKeyboardLED: await client.elements.contains { isKeyboardLED($0) }
        )
    }

    static func bluetoothAddress(for client: HIDDeviceClient) async -> String? {
        guard let property = await client["DeviceAddress"] else {
            return nil
        }

        if let address = property.unsafeObject as? String {
            return PhysicalKeyboardIdentity.normalizedBluetoothAddress(address)
        }

        if let data = property.unsafeObject as? Data, data.count == 6 {
            return data.map { String(format: "%02x", $0) }.joined()
        }

        return nil
    }

    private static func isKeyboardUsage(_ usage: HIDUsage) -> Bool {
        if case .genericDesktop(.keyboard) = usage {
            return true
        }
        if case .genericDesktop(.keypad) = usage {
            return true
        }
        return false
    }

    private static func isMouseUsage(_ usage: HIDUsage) -> Bool {
        if case .genericDesktop(.mouse) = usage {
            return true
        }
        return false
    }

    private static func isKeyboardLED(_ element: HIDElement) -> Bool {
        guard element.type == .output else {
            return false
        }

        if case .led = element.usage {
            return true
        }
        return false
    }
}

/// Classified activation attributed to one Physical Keyboard.
///
/// Raw Physical Keyboard Events and CoreHID service identifiers end here.
struct PhysicalKeyboardActivationActivity: Equatable, Sendable {
    let physicalKeyboardID: PhysicalKeyboardRecordID
}

enum PhysicalKeyboardDiscoveryRecordChange: Equatable, Sendable {
    case connected(physicalKeyboardID: PhysicalKeyboardRecordID)
    case disconnected(physicalKeyboardID: PhysicalKeyboardRecordID)
}

/// Shared internal Physical Keyboard discovery module.
///
/// It owns CoreHID discovery, attribution, connection lifecycle, and
/// Activation Activity classification. Setup management receives the current
/// Physical Keyboard catalog. Activity-Triggered Switching receives only
/// attributed Activation Activity.
@MainActor
final class PhysicalKeyboardDiscovery {
    private let discoverer: any PhysicalKeyboardDiscovering
    private let eventObserver: any PhysicalKeyboardEventObserving
    private var catalog = PhysicalKeyboardCatalog()
    private var discoveryStarted = false
    private var activityObservationStarted = false
    private var observers: [UUID: @MainActor ([PhysicalKeyboard]) -> Void] = [:]
    private var recordChangeObservers: [
        UUID: @MainActor (PhysicalKeyboardDiscoveryRecordChange) -> Void
    ] = [:]
    private var onActivationActivity: (@MainActor (PhysicalKeyboardActivationActivity) -> Void)?

    private(set) var activePhysicalKeyboardID: PhysicalKeyboardRecordID?

    init(
        discoverer: any PhysicalKeyboardDiscovering,
        eventObserver: any PhysicalKeyboardEventObserving
    ) {
        self.discoverer = discoverer
        self.eventObserver = eventObserver
    }

    var physicalKeyboards: [PhysicalKeyboard] {
        catalog.physicalKeyboards.map { keyboard in
            keyboard.markingActive(keyboard.id == activePhysicalKeyboardID)
        }
    }

    private func physicalKeyboard(forServiceID serviceID: UInt64) -> PhysicalKeyboard? {
        catalog.physicalKeyboard(forServiceID: serviceID)
    }

    @discardableResult
    func observeChanges(
        _ observer: @escaping @MainActor ([PhysicalKeyboard]) -> Void
    ) -> UUID {
        let id = UUID()
        observers[id] = observer
        observer(physicalKeyboards)
        return id
    }

    func removeObserver(_ id: UUID) {
        observers[id] = nil
    }

    @discardableResult
    func observeRecordChanges(
        _ observer: @escaping @MainActor (PhysicalKeyboardDiscoveryRecordChange) -> Void
    ) -> UUID {
        let id = UUID()
        recordChangeObservers[id] = observer
        return id
    }

    func removeRecordChangeObserver(_ id: UUID) {
        recordChangeObservers[id] = nil
    }

    func start() {
        guard !discoveryStarted else {
            return
        }

        discoveryStarted = true
        discoverer.start { [weak self] change in
            self?.apply(change)
        }
        publish()
    }

    func stop() {
        stopActivationActivityObservation()
        guard discoveryStarted else {
            return
        }

        discoverer.stop()
        discoveryStarted = false
        catalog = PhysicalKeyboardCatalog()
        publish()
    }

    func startActivationActivityObservation(
        onActivationActivity: @escaping @MainActor (PhysicalKeyboardActivationActivity) -> Void
    ) {
        self.onActivationActivity = onActivationActivity
        guard !activityObservationStarted else {
            return
        }

        activityObservationStarted = true
        eventObserver.start { [weak self] event in
            self?.apply(event)
        }
    }

    func stopActivationActivityObservation() {
        guard activityObservationStarted else {
            onActivationActivity = nil
            return
        }

        eventObserver.stop()
        activityObservationStarted = false
        onActivationActivity = nil
    }

    func markActive(_ physicalKeyboardID: PhysicalKeyboardRecordID) {
        guard activePhysicalKeyboardID != physicalKeyboardID else {
            return
        }

        activePhysicalKeyboardID = physicalKeyboardID
        publish()
    }

    func clearActive(if physicalKeyboardID: PhysicalKeyboardRecordID) {
        guard activePhysicalKeyboardID == physicalKeyboardID else {
            return
        }

        activePhysicalKeyboardID = nil
        publish()
    }

    /// Test seam for feeding raw adapter evidence through the discovery module.
    /// Production callers use the event observer owned by this module.
    func handlePhysicalKeyboardEventForTesting(_ event: PhysicalKeyboardEvent) {
        apply(event)
    }

    private func apply(_ change: PhysicalKeyboardDiscoveryChange) {
        guard discoveryStarted else {
            return
        }

        let previousKeyboards = catalog.physicalKeyboards
        catalog.apply(change)
        switch change {
        case let .connected(facts):
            if let keyboard = physicalKeyboard(forServiceID: facts.serviceID),
               keyboard.id.isIdentityBased
            {
                publishRecordChange(.connected(physicalKeyboardID: keyboard.id))
            }
        case .disconnected:
            let remainingIDs = Set(catalog.physicalKeyboards.map(\.id))
            for keyboard in previousKeyboards
                where keyboard.id.isIdentityBased && !remainingIDs.contains(keyboard.id)
            {
                publishRecordChange(.disconnected(physicalKeyboardID: keyboard.id))
            }
        }
        publish()
    }

    private func apply(_ event: PhysicalKeyboardEvent) {
        guard
            ActivationActivityClassification.isActivationActivity(event),
            let physicalKeyboard = catalog.physicalKeyboard(forServiceID: event.serviceID)
        else {
            return
        }

        onActivationActivity?(
            PhysicalKeyboardActivationActivity(physicalKeyboardID: physicalKeyboard.id)
        )
    }

    private func publish() {
        for observer in observers.values {
            observer(physicalKeyboards)
        }
    }

    private func publishRecordChange(_ change: PhysicalKeyboardDiscoveryRecordChange) {
        for observer in recordChangeObservers.values {
            observer(change)
        }
    }
}
