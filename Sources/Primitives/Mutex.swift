#if canImport(Darwin)
    import Darwin
#elseif os(Windows)
    import ucrt
    import WinSDK
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#else
    #error("Unable to identify your underlying C library.")
#endif

///
@_fixed_layout
public final class Mutex {
    #if os(Windows)
        let mutex: UnsafeMutablePointer<SRWLOCK>
    #else
        let mutex: UnsafeMutablePointer<pthread_mutex_t>
        private let mutexAttr: UnsafeMutablePointer<pthread_mutexattr_t>
    #endif

    /// Initialises an instance of the `Lock` type
    public init() {
        mutex = UnsafeMutablePointer.allocate(capacity: 1)
        #if os(Windows)
            InitializeSRWLock(mutex)
        #else
            mutex.initialize(to: pthread_mutex_t())
            mutexAttr = UnsafeMutablePointer.allocate(capacity: 1)
            mutexAttr.initialize(to: pthread_mutexattr_t())
            pthread_mutexattr_init(mutexAttr)
            pthread_mutexattr_settype(mutexAttr, 0)
            let err = pthread_mutex_init(mutex, mutexAttr)
            precondition(err == 0, "Couldn't initialize pthread_mutex due to \(err)")

        #endif
    }

    deinit {
        #if os(Windows)
            // SRWLOCK does not need to be freed manually
        #else
            pthread_mutexattr_destroy(mutexAttr)
            mutexAttr.deallocate()
            let err = pthread_mutex_destroy(mutex)
            precondition(err == 0, "Couldn't destroy pthread_mutex due to \(err)")
        #endif
        mutex.deallocate()
    }

    /// Acquires the lock.
    public func lock() {
        #if os(Windows)
            AcquireSRWLockExclusive(mutex)
        #else
            let err = pthread_mutex_lock(mutex)
            precondition(err == 0, "\(#function) failed due to \(err)")
        #endif
    }

    /// Releases the lock.
    public func unlock() {
        #if os(Windows)
            ReleaseSRWLockExclusive(mutex)
        #else
            let err = pthread_mutex_unlock(mutex)
            precondition(err == 0, "\(#function) failed due to \(err)")
        #endif
    }

    /// Try to acquire the lock
    /// - Returns: returns true if lock was acquired successfully, otherwise false
    @discardableResult
    public func tryLock() -> Bool {
        #if os(Windows)
            TryAcquireSRWLockExclusive(mutex) != 0
        #else
            pthread_mutex_trylock(mutex) == 0
        #endif
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
    @inlinable
    public func whileLocked<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer {
            unlock()
        }
        return try body()
    }
}
