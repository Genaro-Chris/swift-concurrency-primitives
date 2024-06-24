/// A group of pre-started, idle worker threads that is ready to execute asynchronous
///  code concurrently between all threads.
///
/// This is particularly useful for dispatching multiple heavy workloads off the current thread.
/// It can also block the current thread and wait for all jobs enqueued to finish its execution
///
/// It is very similar to Swift's [DispatchQueue](https://developer.apple.com/documentation/dispatch/dispatchqueue)
public protocol ThreadPool: AnyObject {

    /// Submits a sendable closure for execution in one of the pool's threads
    /// - Parameter body: a non-throwing sendable closure that takes and returns void
    func async(_ body: @escaping @Sendable () -> Void)

    /// Submits a closure for execution in one of the pool's threads
    /// - Parameter body: a non-throwing closure that takes and returns void
    func submit(_ body: @escaping () -> Void)

    /// Cancels the pool execution by cancelling all enqueued un-executed jobs
    func cancel()

    /// Block the caller's thread until all enqueued jobs in the pool are done
    /// executing
    func pollAll()

}
