import Foundation
@testable import Keyameleon

/// Start the concrete switching module, then refresh its current adapters.
/// Tests use the module outcome and internal adapter evidence directly.
@MainActor
func startAndCheck(_ model: KeyameleonSetupModel) {
    if model.activityTriggeredSwitching.testingIsStarted {
        model.activityTriggeredSwitching.checkAgain()
    } else {
        model.activityTriggeredSwitching.start()
    }
}

@MainActor
func isUnavailableKeyboardAssignment(
    _ model: KeyameleonSetupModel,
    for physicalKeyboardID: PhysicalKeyboardRecordID
) -> Bool {
    guard let keyboard = model.physicalKeyboards.first(where: { $0.id == physicalKeyboardID }),
          let assignment = keyboard.keyboardAssignment
    else {
        return false
    }

    return !KeyboardAssignmentAvailability.isAvailable(
        assignment,
        eligibleInputSources: model.eligibleInputSources
    )
}
