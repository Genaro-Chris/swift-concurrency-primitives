import Atomics
import Foundation

/// This provides a thread-coordination mechanism that blocks a group of threads of known size until all threads in that group
///  have reached the latch.
///
/// This enables multiple threads to synchronize the beginning of some computation.
/// Threads may block on the latch until the counter is decremented to zero.
/// There is no possibility to increase or reset the counter, which makes the latch a single-use ``Barrier``.
@_spi(ThreadSync)
@_fixed_layout
public final class Latch {

    private let condition: Condition

    private let mutex: Mutex

    private var blockedThreadsCount: Int

    /// Initialises an instance of the `Latch` type
    /// - Parameter size: the number of threads to use
    /// - Returns: nil if the `size` argument is less than one
    public init?(size: Int) {
        if size < 1 {
            return nil
        }
        blockedThreadsCount = size
        condition = Condition()
        mutex = Mutex()
    }

    /// Decrements the count of the `Latch` instance and blocks the current thread
    /// until the instance's count drops to zero
    public func decrementAndWait() {
        mutex.whileLocked {
            blockedThreadsCount -= 1
            guard blockedThreadsCount != 0 else {
                condition.broadcast()
                return
            }
            condition.wait(mutex: mutex, condition: blockedThreadsCount == 0)
        }
    }

    /// Decrements the count of an `Latch` instance
    /// without blocking the current thread
    public func decrementAlone() {
        mutex.whileLocked {
            blockedThreadsCount -= 1
            guard blockedThreadsCount != 0 else {
                condition.broadcast()
                return
            }
        }
    }

    /// Blocks the current thread until the instance's count drops to zero
    ///
    /// # Warning
    /// This function will deadlock if ``decrementAndWait()`` method
    /// is called more or less than the count passed to the initializer
    public func waitForAll() {
        mutex.whileLocked {
            condition.wait(mutex: mutex, condition: blockedThreadsCount == 0)
        }
    }
}
