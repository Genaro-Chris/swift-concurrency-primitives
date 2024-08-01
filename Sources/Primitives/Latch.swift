import Foundation

/// This provides a thread-coordination mechanism that blocks a
/// group of threads of known size until all threads in that group have reached the latch.
///
/// This enables multiple threads to synchronize the beginning of some computation.
/// Threads may block on the latch until the counter has reached zero.
/// 
/// There is no possibility to reset the counter, which makes the latch a single-use ``Barrier``.
@_spi(ThreadSync)
public final class Latch {

    let condition: Condition

    let mutex: Mutex

    var blockedThreadsCount: Int

    /// Initialises an instance of the `Latch` type
    /// - Parameter size: the number of threads to use
    public init(size: Int) {
        guard size >= 1 else {
            fatalError("Cannot initialize an instance of Latch with count of 0")
        }
        blockedThreadsCount = size
        condition = Condition()
        mutex = Mutex()
    }

    /// Decrements the count of the `Latch` instance and blocks the current thread
    /// until the instance's count reaches zero
    public func decrementAndWait() {
        mutex.whileLockedVoid {
            guard blockedThreadsCount >= 1 else {
                return
            }
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
        mutex.whileLockedVoid {
            guard blockedThreadsCount >= 1 else {
                return
            }
            blockedThreadsCount -= 1
            guard blockedThreadsCount != 0 else {
                condition.broadcast()
                return
            }
        }
    }

    /// Blocks the current thread until the instance's reaches zero
    /// without decrementing
    ///
    /// # Warning
    /// This function will deadlock if ``decrementAndWait()`` or ``decrementAlone``
    /// method
    /// is called more or less than the count passed to the initializer
    public func waitForAll() {
        mutex.whileLockedVoid {
            condition.wait(mutex: mutex, condition: blockedThreadsCount == 0)
        }
    }
}
