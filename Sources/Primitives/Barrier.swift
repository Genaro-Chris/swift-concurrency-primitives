import Atomics
import Foundation

/// This provides a thread-coordination mechanism that blocks a group of threads of known length until all threads
/// in that group have reached the barrier. 
/// 
/// This enables multiple threads to synchronize the beginning of some computation.
/// This is similar to the ``Latch`` type with a major difference of `Barrier` types are reusable:
/// once a group of arriving threads are unblocked, the barrier can be reused
@_spi(ThreadSync)
@frozen
public struct Barrier {

    @usableFromInline let blockedThreadsCount: Locked<Int>

    @usableFromInline let barrier: ManagedAtomic<Bool>

    @usableFromInline let threadCount: Int

    /// Initialises an instance of the `Barrier` type
    /// - Parameter size: the number of threads to use
    /// - Returns: nil if the `size` argument is less than one
    public init?(size: Int) {
        guard size > 0 else {
            return nil
        }
        barrier = ManagedAtomic(false)
        blockedThreadsCount = Locked(size)
        threadCount = size
    }

    /// Increments the count of an `Barrier` instance without blocking the current thread
    @inlinable
    public func decrementAlone() {
        blockedThreadsCount.updateWhileLocked { index in
            guard index != 0 else {
                index = threadCount
                barrier.store(true, ordering: .releasing)
                return
            }
            index -= 1
            if index == 0 {
                index = threadCount
                barrier.store(true, ordering: .releasing)
            }
        }

    }

    /// Increments the count of the `Barrier` instance and
    /// blocks the current thread until the instance's count drops to zero
    @inlinable
    public func decrementAndWait() {
        _ = barrier.compareExchange(
            expected: true, desired: false, ordering: .acquiringAndReleasing)
        blockedThreadsCount.updateWhileLocked { index in
            guard index != 0 else {
                index = threadCount
                barrier.store(true, ordering: .releasing)
                return
            }
            index -= 1
            if index == 0 {
                index = threadCount
                barrier.store(true, ordering: .releasing)
            }
        }
        while !barrier.load(ordering: .acquiring) {
            Thread.yield()
        }
    }
}
