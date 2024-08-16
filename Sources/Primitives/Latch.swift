import Foundation

/// This provides a thread-coordination mechanism that blocks a
/// group of threads of known size until all threads in that group have reached the latch.
///
/// This enables multiple threads to synchronize the beginning of some computation.
/// Threads may block on the latch until the counter has reached zero.
///
/// There is no possibility to reset the counter, which makes the latch a single-use ``Barrier``.
@_spi(ThreadSync)
public struct Latch {

    let blockedThreadsLock: ConditionalLockBuffer<Int>

    /// Initialises an instance of the `Latch` type
    /// - Parameter size: the number of threads to use
    public init(size: Int) {
        guard size >= 1 else {
            fatalError("Cannot initialise an instance of Latch with count of 0")
        }
        blockedThreadsLock = ConditionalLockBuffer.create(value: size)
    }

    /// Decrements the count of the `Latch` instance and blocks the current thread
    /// until the instance's count reaches zero
    public func decrementAndWait() {
        blockedThreadsLock.interactWhileLocked { index, conditionLock in
            guard index >= 1 else { return }
            index -= 1
            guard index != 0 else {
                conditionLock.broadcast()
                return
            }
            conditionLock.wait(for: index == 0)
        }
    }

    /// Decrements the count of an `Latch` instance
    /// without blocking the current thread
    public func decrementAlone() {
        blockedThreadsLock.interactWhileLocked { index, conditionLock in
            guard index >= 1 else { return }
            index -= 1
            if index == 0 {
                conditionLock.broadcast()
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
        blockedThreadsLock.interactWhileLocked { index, conditionLock in
            conditionLock.wait(for: index == 0)
        }
    }
}
