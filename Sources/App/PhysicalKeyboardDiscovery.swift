import CoreHID
import Foundation

@MainActor
protocol PhysicalKeyboardDiscovering: AnyObject {
    func start(onChange: @escaping @MainActor (PhysicalKeyboardDiscoveryChange) -> Void)
    func stop()
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

        guard await client.primaryUsage == .genericDesktop(.keyboard) else {
            return nil
        }

        // CoreHID's unique ID is software-based. The hardware anchor is required
        // before the identity can make a Physical Keyboard assignable.
        let isBuiltIn = await client.isBuiltIn
        let serialNumber = await client.serialNumber
        let identity = await client.uniqueID.flatMap {
            PhysicalKeyboardIdentity(
                rawValue: $0,
                isBuiltIn: isBuiltIn,
                serialNumber: serialNumber
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
