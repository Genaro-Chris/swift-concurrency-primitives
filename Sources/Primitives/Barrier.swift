import Foundation

/// This provides a thread-coordination mechanism that blocks a group of a fixed number of threads until all threads
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
    var generation: FlagStage

    /// Initialises an instance of the `Barrier` type
    /// - Parameter size: the number of threads to use
    public init(size: Int) {
        guard size >= 1 else {
            fatalError("Cannot initialize an instance of Barrier with a size less than 1")
        }
        condition = Condition()
        mutex = Mutex()
        blockedThreadsCount = 0
        threadsCount = size
        generation = .wait
    }

    /// Increments the count of an `Barrier` instance without blocking the current thread
    public func arriveAlone() {
        mutex.whileLockedVoid {
            blockedThreadsCount += 1
            guard blockedThreadsCount == threadsCount else {
                return
            }
            blockedThreadsCount = 0
            generation.toggle()
            condition.broadcast()
        }
    }

    /// Increments the count of the `Barrier` instance and
    /// blocks the current thread until all the other threads has arrived at the barrier
    public func arriveAndWait() {
        mutex.whileLockedVoid {
            let currentGeneration = generation
            blockedThreadsCount += 1
            guard blockedThreadsCount != threadsCount else {
                blockedThreadsCount = 0
                generation.toggle()
                condition.broadcast()
                return
            }
            condition.wait(mutex: mutex, until: currentGeneration == generation)
        }
    }
}

/// Signifies a barrier generation state
///
/// This is more efficient than using Int type for barrier generation
enum FlagStage: Equatable {

    case wait, inProgress

    mutating func toggle() {
        switch self {
        case .wait:
            self = .inProgress
        case .inProgress:
            self = .wait
        }
    }
}
