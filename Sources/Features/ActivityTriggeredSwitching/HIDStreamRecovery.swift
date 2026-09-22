/// Restart policy for the CoreHID streams the system adapters keep open.
///
/// A cancelled task is `stop()`. Any other exit, including a thrown stream
/// error or a finished `for try await`, must subscribe again.
enum HIDStreamRecovery {
    static func shouldRestart(taskWasCancelled: Bool) -> Bool {
        !taskWasCancelled
    }

    /// Kept in the policy so a failing Mac cannot tight-loop on resubscribe.
    static let restartDelay: Duration = .seconds(1)
}
