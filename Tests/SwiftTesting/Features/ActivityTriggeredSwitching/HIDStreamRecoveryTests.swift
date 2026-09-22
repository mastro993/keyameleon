import Testing
@testable import Keyameleon

@Test("A cancelled stream stays stopped")
func cancelledStreamStaysStopped() {
    #expect(!HIDStreamRecovery.shouldRestart(taskWasCancelled: true))
}

@Test("An ended or failed stream restarts")
func endedStreamRestarts() {
    #expect(HIDStreamRecovery.shouldRestart(taskWasCancelled: false))
}

@Test("Restart delay is at least one second")
func restartDelayIsAtLeastOneSecond() {
    #expect(HIDStreamRecovery.restartDelay >= .seconds(1))
}
