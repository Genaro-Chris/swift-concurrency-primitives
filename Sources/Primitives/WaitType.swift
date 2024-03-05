/// Provides a way for ending ``ThreadPool`` types
public enum WaitType: Sendable {
    /// Cancels all tasks this means waits for any job that is currently running to
    /// finish its execution then cancels the remaining jobs
    case cancelAll
    /// Waits for all tasks enqueued to finish their execution
    case waitForAll
}
