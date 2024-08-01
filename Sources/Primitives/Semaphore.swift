import Foundation

/// This serves as an indicator for task or thread has finished its execution
///
/// This waits for a number of threads or tasks to finish.
/// 
/// The number of threads or tasks to be awaited are specified at initialization.
/// Then each of the threads or tasks runs and calls ``notify()`` when finished.
/// 
/// The ``waitForAll()`` method is then used to block the current thread,
/// waiting until all threads or tasks have finished.
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
public final class LockSemaphore {

    let mutex: Mutex

    let condition: Condition

    var index: Int

    /// Initializes a `LockSemaphore` instance with a fixed number of threads or task
    /// - Parameter size: maximum number of tasks or threads to await
    public init(size: Int) {
        guard size >= 1 else {
            fatalError("Cannot initialize an instance of Semaphore with count of 0")
        }
        index = size
        mutex = Mutex()
        condition = Condition()
    }

    /// Indicates that this thread or task has finished its execution.
    /// This should be called only inside the thread or task
    public func notify() {
        mutex.whileLockedVoid {
            guard index >= 1 else { return }
            index -= 1
            if index == 0 {
                condition.broadcast()
            }
        }

    }

    /// Blocks until there is no more thread or task running
    public func waitForAll() {
        mutex.whileLockedVoid {
            condition.wait(mutex: mutex, condition: index == 0)
        }
    }
}
