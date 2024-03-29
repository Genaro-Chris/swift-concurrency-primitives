import Foundation

#if canImport(Darwin)
    import Darwin
    public final class DarwinMutex {
        let lock: UnsafeMutablePointer<os_unfair_lock>

        init() {
            lock = UnsafeMutablePointer.allocate(capacity: 1)
            lock.initialize(to: os_unfair_lock())
        }

        /// Acquire the lock.
        @usableFromInline func lock() {
            os_unfair_lock_lock(lock)
        }

        /// Release the lock.
        @usableFromInline func unlock() {
            os_unfair_lock_lock(lock)
        }

        deinit {
            lock.deinitialize()
            lock.deallocate()
        }
    }

#endif
