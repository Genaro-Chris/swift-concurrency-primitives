import Foundation

/// This provides a thread-coordination mechanism that blocks a group of a fixed number of threads until all threads
/// in that group have reached the barrier.
///
/// This enables multiple threads to synchronize the beginning of some computation.
/// This is similar to the ``Latch`` type with a major difference of `Barrier` types been reusable:
/// once a group of arriving threads are unblocked, the barrier can be reused
@_spi(ThreadSync)
public struct Barrier {

    let blockedThreadsLock: ConditionalLockBuffer<InnerState>

    /// Initialises an instance of the `Barrier` type
    /// - Parameter size: the number of threads to use
    public init(size: Int) {
        guard size >= 1 else {
            fatalError("Cannot initialise an instance of Barrier with a size less than 1")
        }
        blockedThreadsLock = ConditionalLockBuffer.create(value: InnerState(size: size))
    }

    /// Increments the count of an `Barrier` instance without blocking the current thread
    public func arriveAlone() {
        blockedThreadsLock.interactWhileLocked { inner, conditionLock in
            inner.incrementCounter()
            guard inner.counter == inner.threadsCount else {
                return
            }
            inner.resetCounter()
            inner.changeState()
            conditionLock.broadcast()
        }
    }

    /// Increments the count of the `Barrier` instance and
    /// blocks the current thread until all the other threads has arrived at the barrier
    public func arriveAndWait() {
        blockedThreadsLock.interactWhileLocked { inner, conditionLock in
            let currentGeneration: Int = inner.generation
            inner.incrementCounter()
            guard inner.counter == inner.threadsCount else {
                conditionLock.wait(until: currentGeneration == inner.generation)
                return
            }
            inner.resetCounter()
            inner.changeState()
            conditionLock.broadcast()
        }
    }
}

struct InnerState {

    private(set) var counter: Int

    // Flag to differentiate barrier generations (avoid race conditions)
    private(set) var generation: Int

    let threadsCount: Int

    init(size: Int) {
        counter = 0
        generation = 0
        threadsCount = size
    }

    mutating func incrementCounter() {
        counter += 1
    }

    mutating func resetCounter() {
        counter = 0
    }

    mutating func changeState() {
        generation += 1
    }
}
