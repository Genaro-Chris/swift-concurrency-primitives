// 
final class PThreadBarrier {
    private let condition = Condition()
    private let mutex = Mutex()
    private var blockedThreadIndex = 0
    private let threadCount: Int

    init?(count: Int) {
        if count < 1 {
            return nil
        }
        threadCount = count
    }

    // Decrements the counter then blocks the current thread until counter is 0
    func arriveAndWait() {
        mutex.whileLocked {
            blockedThreadIndex += 1
            guard blockedThreadIndex != threadCount else {
                blockedThreadIndex = 0
                condition.broadcast()
                return
            }
            condition.wait(mutex: mutex, condition: blockedThreadIndex == 0)
        }
    }

    // Decrements the counter without blocking
    func arriveAlone() {
        mutex.whileLocked {
            blockedThreadIndex += 1
            guard blockedThreadIndex != threadCount else {
                blockedThreadIndex = 0
                condition.broadcast()
                return
            }
        }
    }
}
