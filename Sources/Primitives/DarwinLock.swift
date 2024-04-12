import Foundation

#if canImport(Darwin)
    import Darwin

    public final class DarwinLock {

        private let lock: UnsafeMutablePointer<os_unfair_lock>

        init() {
            lock = UnsafeMutablePointer.allocate(capacity: 1)
            lock.initialize(to: os_unfair_lock())
        }

        deinit {
            lock.deinitialize()
            lock.deallocate()
        }

        /// Acquire the lock.
        func lock() {
            os_unfair_lock_lock(lock)
        }

        /// Release the lock.
        func unlock() {
            os_unfair_lock_unlock(lock)
        }

        /// Tries to acquire the lock for the duration for the closure passed as
        /// argument and releases the lock immediately after the closure has finished
        /// its execution regardless of how it finishes
        ///
        /// - Parameter body: closure to be executed while being protected by the lock
        /// - Returns: value returned from the body closure
        ///
        /// # Note
        /// Avoid calling long running or blocking code while using this function
        @_transparent @_alwaysEmitIntoClient
        public func whileLocked<T>(_ body: () throws -> T) rethrows -> T {
            lock()
            defer {
                unlock()
            }
            return try body()
        }
    }
#endif
