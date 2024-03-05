import Atomics
import Foundation

/// This serves as an indicator for task or thread has finished its execution
/// 
/// This waits for a number of threads or tasks to finish.
/// The number of threads or tasks to be awaited are specified at initialization.
/// Then each of the threads or tasks runs and calls ``notify()`` when finished.
/// The ``waitForAll()`` method is then used to block the current thread, waiting until all threads or tasks have finished.
///
/// # Example
/// ```swift
/// let taskNotifier = Notifier(size: 3)
///
/// for _ in 1 ... 3 {
///     Task {
///         // do some async work here...
///         taskNotifier.notify
///     }
/// }
/// 
/// // do some other work here
/// // wait for the async work to finish before continuing
/// taskNotifier.waitForAll()
/// ```
///
@frozen
public struct Notifier {

    @usableFromInline let max: Int

    @usableFromInline let index: ManagedAtomic<Int>

    /// Initializes a `Notifier` instance with a fixed number of threads or task
    /// - Parameter size: maximum number of tasks or threads to await
    /// - Returns: nil if the `size` argument is less than zero
    @inlinable
    public init?(size: Int) {
        guard size >= 0 else {
            return nil
        }
        max = size
        index = ManagedAtomic(0)
    }

    /// Indicates that this thread or task has finished its execution.
    /// This should be called only inside the thread or task
    @inlinable
    public func notify() {
        guard index.load(ordering: .relaxed) <= max else {
            return
        }
        index.wrappingIncrement(ordering: .acquiringAndReleasing)
    }

    /// Blocks until there is no more thread or task running
    @inlinable
    public func waitForAll() {
        while !index.weakCompareExchange(
            expected: max, desired: 0, ordering: .acquiringAndReleasing
        ).exchanged {
            Thread.yield()
        }
    }
}
