/// Provides a way for ending ``ThreadPool`` types
@frozen
public enum WaitType {
    /// Cancels all enqueued, un-executed tasks which means it does not wait
    case cancelAll
    /// Waits for all tasks enqueued to finish their execution
    case waitForAll
}
