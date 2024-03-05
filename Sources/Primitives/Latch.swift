import Atomics
import Foundation

/// This provides a thread-coordination mechanism that blocks a group of threads of known size until all threads in that group
///  have reached the latch. 
/// 
/// This enables multiple threads to synchronize the beginning of some computation.
/// Threads may block on the latch until the counter is decremented to zero.
/// There is no possibility to increase or reset the counter, which makes the latch a single-use ``Barrier``. 
@_spi(ThreadSync)
@frozen
public struct Latch {

    @usableFromInline let blockedThreadsCount: ManagedAtomic<Int>

    @usableFromInline let latch: ManagedAtomic<Bool>

    /// Initialises an instance of the `Latch` type
    /// - Parameter size: the number of threads to use
    /// - Returns: nil if the `size` argument is less than one
    public init?(size: Int) {
        guard size > 0 else {
            return nil
        }
        blockedThreadsCount = ManagedAtomic(size)
        latch = ManagedAtomic(false)
    }

    /// Decrements the count of the `Latch` instance and blocks the current thread 
    /// until the instance's count drops to zero
    @inlinable
    public func decrementAndWait() {
        guard blockedThreadsCount.load(ordering: .acquiring) != 0 else {
            return
        }
        guard
            blockedThreadsCount.wrappingDecrementThenLoad(
                ordering: .acquiringAndReleasing) != 0
        else {
            latch.store(true, ordering: .releasing)
            return
        }
        while !latch.load(ordering: .acquiring) {
            Thread.yield()
        }

    }

    /// Decrements the count of an `Latch` instance
    /// without blocking the current thread
    @inlinable
    public func decrementAlone() {
        guard blockedThreadsCount.load(ordering: .acquiring) != 0 else { return }
        guard
            blockedThreadsCount.wrappingDecrementThenLoad(
                ordering: .acquiringAndReleasing) == 0
        else {
            return
        }
        latch.store(true, ordering: .releasing)
    }

    /// Blocks the current thread until the instance's count drops to zero
    ///
    /// # Warning 
    /// This function will deadlock if ``decrementAndWait()`` method 
    /// is called more or less than the count passed to the initializer
    @inlinable
    public func waitForAll() {
        while !latch.load(ordering: .acquiring) {
            Thread.yield()
        }
    }
}
