import Foundation

#if canImport(Darwin)
    import Darwin

    /// A thin wrapper over os_unfair_lock type for darwin system
    final class DarwinLock {

        let unfair_lock: UnsafeMutablePointer<os_unfair_lock>

        init() {
            unfair_lock = UnsafeMutablePointer.allocate(capacity: 1)
            unfair_lock.initialize(to: os_unfair_lock())
        }

        deinit {
            unfair_lock.deinitialize(count: 1)
            unfair_lock.deallocate()
        }

        /// Acquire the lock.
        func lock() {
            os_unfair_lock_lock(unfair_lock)
        }

        /// Release the lock.
        func unlock() {
            os_unfair_lock_unlock(unfair_lock)
        }

        /// Tries to acquire the lock for the duration for the closure passed as
        /// argument and releases the lock immediately after the closure has finished
        /// its execution regardless of how it finishes
        ///
        /// - Parameter body: closure to be executed while being protected by the lock
        /// - Returns: value returned from the body closure
        ///
        /// # Warning
        /// Avoid calling long running or blocking code while using this function
        func whileLocked<T>(_ body: () throws -> T) rethrows -> T {
            lock()
            defer {
                unlock()
            }
            return try body()
        }

        /// Tries to acquire the lock for the duration for the closure passed as
        /// argument and releases the lock immediately after the closure has finished
        /// its execution regardless of how it finishes
        ///
        /// - Parameter body: closure to be executed while being protected by the lock
        ///
        /// # Warning
        /// Avoid calling long running or blocking code while using this function
        func whileLockedVoid(_ body: () throws -> Void) rethrows {
            lock()
            defer {
                unlock()
            }
            return try body()
        }
    }
#endif
