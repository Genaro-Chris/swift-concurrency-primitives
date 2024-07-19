import Foundation

/// This provides a thread-coordination mechanism that blocks a group of threads of known length until all threads
/// in that group have reached the barrier.
///
/// This enables multiple threads to synchronize the beginning of some computation.
/// This is similar to the ``Latch`` type with a major difference of `Barrier` types been reusable:
/// once a group of arriving threads are unblocked, the barrier can be reused
@_spi(ThreadSync)
public final class Barrier {

    let condition: Condition

    let mutex: Mutex

    var blockedThreadsCount: Int

    let threadsCount: Int

    // Flag to differentiate barrier generations (avoid race conditions)
    var generation: Int

    /// Initialises an instance of the `Barrier` type
    /// - Parameter size: the number of threads to use
    /// - Returns: nil if the `size` argument is less than one
    public init(size: Int) {
        guard size >= 1 else {
            fatalError("Cannot initialize an instance of Barrier with a size less than 1")
        }
        condition = Condition()
        mutex = Mutex()
        blockedThreadsCount = 0
        threadsCount = size
        generation = 0
    }

    /// Increments the count of an `Barrier` instance without blocking the current thread
    public func arriveAlone() {
        mutex.whileLockedVoid {
            blockedThreadsCount += 1
            guard blockedThreadsCount == threadsCount else {
                return
            }
            blockedThreadsCount = 0
            generation += 1
            condition.broadcast()
        }
    }

    /// Increments the count of the `Barrier` instance and
    /// blocks the current thread until all the threads has arrived at the barrier
    public func arriveAndWait() {
        mutex.whileLockedVoid {
            let currentGeneration: Int = generation
            blockedThreadsCount += 1
            guard blockedThreadsCount != threadsCount else {
                blockedThreadsCount = 0
                generation += 1
                condition.broadcast()
                return
            }
            condition.wait(mutex: mutex, until: currentGeneration == generation)
        }
    }
}
