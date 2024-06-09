import Foundation

/// This waits for a number of threads to finish.
///
/// The caller threads calls ``enter()`` a number of times to set the number of
/// threads to wait for. Then each of the threads runs and calls ``done()`` when finished.
///  Then, ``waitForAll()`` can be used to block until all threads have finished.
///
/// This is similar to Go's [sync.WaitGroup](https://pkg.go.dev/sync#WaitGroup)
/// and Swift's [DispatchGroup](https://developer.apple.com/documentation/dispatch/dispatchgroup)
///
/// # Example
///
/// ```swift
/// let waitGroup = WaitGroup()
/// for _ in 1...5 {
///     waitGroup.enter()
///     DispatchQueue.global.async {
///         defer {
///             waitGroup.done()
///         }
///         // do some async or concurrent work
///     }
/// }
/// waitGroup.waitForAll()
/// ```
public final class WaitGroup {

    var index: Int

    let mutex: Mutex

    let condition: Condition

    /// Initializes a `WaitGroup` instance
    public init() {
        index = 0
        mutex = Mutex()
        condition = Condition()
    }

    /// This indicates that a new thread is about to start.
    /// This should be called only outside the thread doing the work.
    public func enter() {
        mutex.whileLocked {
            index += 1
        }
    }

    /// Indicates that it is done executing this thread.
    /// This should be called only in the thread doing the work.
    public func done() {
        mutex.whileLocked {
            guard index >= 1 else { return }
            index -= 1
            if index == 0 {
                condition.broadcast()
            }
        }
    }

    /// Blocks until there is no more thread running
    #if compiler(>=5.7) || swift(>=5.7)
        @available(
            *, noasync,
            message:
                "This function blocks the calling thread and therefore shouldn't be called from an async context"
        )
    #endif
    public func waitForAll() {
        mutex.whileLocked {
            condition.wait(mutex: mutex, condition: index == 0)
        }
    }
}
