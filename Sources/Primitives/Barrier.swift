import Atomics
import Foundation

/// This provides a thread-coordination mechanism that blocks a group of threads of known length until all threads
/// in that group have reached the barrier.
///
/// This enables multiple threads to synchronize the beginning of some computation.
/// This is similar to the ``Latch`` type with a major difference of `Barrier` types are reusable:
/// once a group of arriving threads are unblocked, the barrier can be reused
@_spi(ThreadSync)
@_fixed_layout
public final class Barrier {

    private let condition: Condition

    private let mutex: Mutex

    private var blockedThreadsCount: Int

    private let threadCount: Int

    /// Initialises an instance of the `Barrier` type
    /// - Parameter size: the number of threads to use
    /// - Returns: nil if the `size` argument is less than one
    public init(size: Int) {
        if size < 1 {
            fatalError("Cannot initialize an instance of Barrier with count of 0")
        }
        condition = Condition()
        mutex = Mutex()
        blockedThreadsCount = 0
        threadCount = size
    }

    /// Increments the count of an `Barrier` instance without blocking the current thread
    public func arriveAlone() {
        mutex.whileLocked {
            blockedThreadsCount += 1
            guard blockedThreadsCount != threadCount else {
                blockedThreadsCount = 0
                condition.broadcast()
                return
            }
        }
    }

    /// Increments the count of the `Barrier` instance and
    /// blocks the current thread until the instance's count drops to zero
    public func arriveAndWait() {
        mutex.whileLocked {
            blockedThreadsCount += 1
            guard blockedThreadsCount != threadCount else {
                blockedThreadsCount = 0
                condition.broadcast()
                return
            }
            condition.wait(mutex: mutex, condition: blockedThreadsCount == 0)
        }
    }
}
