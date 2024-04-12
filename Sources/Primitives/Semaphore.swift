import Atomics
import Foundation

/// This serves as an indicator for task or thread has finished its execution
///
/// This waits for a number of threads or tasks to finish.
/// The number of threads or tasks to be awaited are specified at initialization.
/// Then each of the threads or tasks runs and calls ``notify()`` when finished.
/// The ``waitForAll()`` method is then used to block the current thread,
/// waiting until all threads or tasks have finished.
///
/// # Example
/// ```swift
/// let taskSemaphore = Semaphore(size: 3)
///
/// for _ in 1 ... 3 {
///     Task {
///         // do some async work here...
///         taskSemaphore.notify
///     }
/// }
///
/// // do some other work here
/// // wait for the async work to finish before continuing
/// taskSemaphore.waitForAll()
/// ```
///
@frozen
public struct Semaphore {

    private let index: ManagedAtomic<Int>

    private let mutex: Mutex

    private let condition: Condition

    /// Initializes a `Semaphore` instance with a fixed number of threads or task
    /// - Parameter size: maximum number of tasks or threads to await
    /// - Returns: nil if the `size` argument is less than zero
    public init(size: Int) {
        guard size >= 0 else {
            preconditionFailure("Cannot initialize an instance of Semaphore with count of 0")
        }
        index = ManagedAtomic(size)
        mutex = Mutex()
        condition = Condition()
    }

    /// Indicates that this thread or task has finished its execution.
    /// This should be called only inside the thread or task
    public func notify() {
        guard index.load(ordering: .relaxed) >= 1 else { return }
        if index.wrappingDecrementThenLoad(ordering: .acquiringAndReleasing) == 0 {
            condition.broadcast()
        }
    }

    /// Blocks until there is no more thread or task running
    public func waitForAll() {
        mutex.whileLocked {
            condition.wait(mutex: mutex, condition: index.load(ordering: .acquiring) == 0)
        }
    }
}
