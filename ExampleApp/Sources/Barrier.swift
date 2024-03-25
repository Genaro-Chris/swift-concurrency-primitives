#if os(macOS)
    import Darwin
#else
    import Glibc
#endif

//
class PThreadBarrier {
    let barrier: UnsafeMutablePointer<pthread_barrier_t>
    let barrierAttr: UnsafeMutablePointer<pthread_barrierattr_t>

    public init(count: UInt32) {
        barrier = UnsafeMutablePointer.allocate(capacity: 1)
        barrier.initialize(to: pthread_barrier_t())
        barrierAttr = UnsafeMutablePointer.allocate(capacity: 1)
        barrierAttr.initialize(to: pthread_barrierattr_t())
        pthread_barrier_init(barrier, barrierAttr, count)
    }

    deinit {
        barrierAttr.deinitialize(count: 1)
        barrier.deinitialize(count: 1)
        barrierAttr.deallocate()
        barrier.deallocate()
    }

     // Decrements the counter then blocks the current thread until counter is 0
    func arriveAndWait() {
        pthread_barrier_wait(barrier)
    }
}
