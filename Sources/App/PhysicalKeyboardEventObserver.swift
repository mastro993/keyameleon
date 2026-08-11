import CoreHID
import Foundation

@MainActor
protocol PhysicalKeyboardEventObserving: AnyObject {
    func start(onEvent: @escaping @MainActor (PhysicalKeyboardEvent) -> Void)
    func stop()
}

/// Listen-only CoreHID observation. Never seizes a Physical Keyboard or sends events.
@MainActor
final class SystemPhysicalKeyboardEventObserver: PhysicalKeyboardEventObserving {
    private var managerTask: Task<Void, Never>?
    private var deviceTasks: [UInt64: Task<Void, Never>] = [:]
    private var onEvent: (@MainActor (PhysicalKeyboardEvent) -> Void)?

    func start(onEvent: @escaping @MainActor (PhysicalKeyboardEvent) -> Void) {
        stop()
        self.onEvent = onEvent

        managerTask = Task { @MainActor in
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
                        startMonitoring(deviceReference: reference)
                    case let .deviceRemoved(reference):
                        stopMonitoring(serviceID: reference.deviceID)
                    @unknown default:
                        continue
                    }
                }
            } catch {
                // Observation is fail-closed. A later permission refresh restarts it.
            }
        }
    }

    func stop() {
        managerTask?.cancel()
        managerTask = nil

        for task in deviceTasks.values {
            task.cancel()
        }
        deviceTasks.removeAll()
        onEvent = nil
    }

    private func startMonitoring(deviceReference: HIDDeviceClient.DeviceReference) {
        let serviceID = deviceReference.deviceID
        stopMonitoring(serviceID: serviceID)

        deviceTasks[serviceID] = Task { @MainActor in
            guard let client = HIDDeviceClient(deviceReference: deviceReference) else {
                return
            }

            // Never call seizeDevice. Listen-only public observation only.
            let elements = await client.elements.filter { element in
                Self.isSupportedActivationElement(element)
            }

            guard !elements.isEmpty else {
                return
            }

            // Ephemeral previous values for transition classification only.
            // Never retained beyond this task; never logged or persisted.
            var previousByElement: [String: Int64] = [:]

            do {
                for try await notification in await client.monitorNotifications(
                    reportIDsToMonitor: [],
                    elementsToMonitor: elements
                ) {
                    guard !Task.isCancelled else {
                        return
                    }

                    switch notification {
                    case let .elementUpdates(values):
                        for value in values {
                            let key = value.element.description
                            let current = value.integerValue(asTypeTruncatingIfNeeded: Int64.self)
                            let previous = previousByElement[key]
                            previousByElement[key] = current

                            guard
                                let kind = PhysicalKeyboardElementTransition.kind(
                                    previous: previous,
                                    current: current
                                )
                            else {
                                continue
                            }

                            // Drop Key Content immediately; only emit attribution + kind.
                            onEvent?(
                                PhysicalKeyboardEvent(
                                    serviceID: serviceID,
                                    kind: kind
                                )
                            )
                        }
                    case .deviceRemoved:
                        return
                    case .deviceSeized, .deviceUnseized, .inputReport:
                        // Ignore seize lifecycle and raw reports; element path is primary.
                        continue
                    @unknown default:
                        continue
                    }
                }
            } catch {
                // Device-level observation ends quietly; manager stream may rematch later.
            }
        }
    }

    private func stopMonitoring(serviceID: UInt64) {
        deviceTasks[serviceID]?.cancel()
        deviceTasks[serviceID] = nil
    }

    /// Normal, modifier, function, media, lock, and exposed special keys.
    private static func isSupportedActivationElement(_ element: HIDElement) -> Bool {
        guard element.type == .input else {
            return false
        }

        switch element.usage {
        case .keyboardOrKeypad:
            return true
        case .consumer:
            return true
        default:
            return false
        }
    }
}

/// Test double / no-op default when observation is not started.
@MainActor
final class NoOpPhysicalKeyboardEventObserver: PhysicalKeyboardEventObserving {
    func start(onEvent: @escaping @MainActor (PhysicalKeyboardEvent) -> Void) {}
    func stop() {}
}
