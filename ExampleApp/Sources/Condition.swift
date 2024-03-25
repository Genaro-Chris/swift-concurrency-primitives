#if os(macOS)
    import Darwin
#else
    import Glibc
#endif

import Foundation

//
final class Condition {
    private let condition: UnsafeMutablePointer<pthread_cond_t>
    private let conditionAttr: UnsafeMutablePointer<pthread_condattr_t>

    init() {
        condition = UnsafeMutablePointer.allocate(capacity: 1)
        condition.initialize(to: pthread_cond_t())
        conditionAttr = UnsafeMutablePointer.allocate(capacity: 1)
        conditionAttr.initialize(to: pthread_condattr_t())
        pthread_cond_init(condition, conditionAttr)
    }

    deinit {
        conditionAttr.deinitialize(count: 1)
        condition.deinitialize(count: 1)
        conditionAttr.deallocate()
        condition.deallocate()
    }

    // Blocks the current thread until the condition return true or unblocked by ``signal()`` or ``broadcast()`` method
    func wait(mutex: Mutex, condition: @autoclosure () -> Bool) {
        while !condition() {
            pthread_cond_wait(self.condition, mutex.mutex)
        }

    }

    // Blocks the current thread until unblocked by ``signal()`` or ``broadcast()`` method
    func wait(mutex: Mutex) {
        pthread_cond_wait(condition, mutex.mutex)
    }

    func signal() {
        pthread_cond_signal(condition)
    }

    func broadcast() {
        pthread_cond_broadcast(condition)
    }
}
