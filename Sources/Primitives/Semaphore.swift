import Foundation

/// This serves as an indicator for task or thread has finished its execution
///
/// This waits for a number of threads to finish.
///
/// The number of threads to be awaited are specified at initialization.
/// Then each of the threads runs and calls ``notify()`` when finished.
///
/// The ``waitForAll()`` method is then used to block the current thread,
/// waiting until all threads have finished.
///
/// This is useful in threads coordination if the number of threads is
/// already known
///
/// # Example
/// ```swift
/// let taskSemaphore = Semaphore(size: 3)
///
/// for _ in 1 ... 3 {
///     DispatchQueue.global().async {
///         // do some async work here...
///         taskSemaphore.notify()
///     }
/// }
///
/// // do some other work here
/// // wait for the async work to finish before continuing
/// taskSemaphore.waitForAll()
/// ```
///
public struct LockSemaphore {

    let indexLock: ConditionalLockBuffer<Int>

    /// Initialises a `LockSemaphore` instance with a fixed number of threads
    /// - Parameter size: maximum number of tasks or threads to await
    public init(size: Int) {
        guard size >= 1 else {
            fatalError("Cannot initialise an instance of Semaphore with count of 0")
        }
        indexLock = ConditionalLockBuffer.create(value: size)
    }

    /// Indicates that this thread has finished its execution.
    /// This should be called only inside the thread
    public func notify() {
        indexLock.interactWhileLocked { index, conditionLock in
            guard index >= 1 else { return }
            index -= 1
            if index == 0 {
                conditionLock.broadcast()
            }
        }
    }

    /// Blocks until there is no more thread running
    public func waitForAll() {
        indexLock.interactWhileLocked { index, conditionLock in
            conditionLock.wait(for: index == 0)
        }
    }
}
