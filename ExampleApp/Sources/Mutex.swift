#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    import Darwin
#else
    import Glibc
#endif

import Foundation

// A threading mutex based on `libpthread` instead of `libdispatch`.
//
// This object provides a mutex on top of a single `pthread_mutex_t`. This kind
// of mutex is safe to use with `libpthread`-based threading models
class Mutex {

    let mutex: UnsafeMutablePointer<pthread_mutex_t>
    private let mutexAttr: UnsafeMutablePointer<pthread_mutexattr_t>

    init() {
        mutex = UnsafeMutablePointer.allocate(capacity: 1)
        mutex.initialize(to: pthread_mutex_t())
        mutexAttr = UnsafeMutablePointer.allocate(capacity: 1)
        mutexAttr.initialize(to: pthread_mutexattr_t())
        pthread_mutexattr_settype(mutexAttr, 1)
        pthread_mutex_init(mutex, mutexAttr)
    }

    deinit {
        mutexAttr.deinitialize(count: 1)
        mutex.deinitialize(count: 1)
        mutexAttr.deallocate()
        mutex.deallocate()
    }

    //
    func lock() {
        pthread_mutex_lock(mutex)
    }

    func unlock() {
        pthread_mutex_unlock(mutex)
    }

    @discardableResult
    @inlinable
    func whileLocked<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
