import Foundation

/// This waits for a number of threads to finish.
///
/// The caller threads calls ``enter()`` a number of times to set the number of
/// threads to wait for. Then each of the threads runs and calls ``done()`` when finished.
///
///  The ``waitForAll()`` method will block until all threads have finished their execution.
///
/// This is useful for threads coordination if the number of threads is not
/// previously known
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
public struct WaitGroup {

    let indexLock: ConditionalLockBuffer<Int>

    /// Initialises a `WaitGroup` instance
    public init() {
        indexLock = ConditionalLockBuffer.create(value: 0)
    }

    /// This indicates that a new thread is about to start.
    /// This should be called only outside the thread doing the work.
    public func enter() {
        indexLock.interactWhileLocked { index, conditionLock in
            index += 1
        }
    }

    /// Indicates that it is done executing this thread.
    /// This should be called only in the thread doing the work.
    public func done() {
        indexLock.interactWhileLocked { index, conditionLock in
            guard index >= 1 else { return }
            index -= 1
            if index == 0 {
                conditionLock.broadcast()
            }
        }
    }

    /// Blocks until there is no more thread running
    ///
    /// This method blocks the current thread execution only if one or more
    /// calls to the `enter` method until the same number of calls as been made to the ``done`` method
    public func waitForAll() {
        indexLock.interactWhileLocked { index, conditionLock in
            conditionLock.wait(for: index == 0)
        }
    }
}
