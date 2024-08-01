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

/// A threading mutex based on `libpthread` library on non windows systems or Slim
/// Reader-Writer Locks on windows system.
///
/// This object provides a safe abstraction on top of a single `pthread_mutex_t` or `SRWLOCK`. This kind
/// of mutex is safe to use with `libpthread`-based threading models as well as windows
/// systems.
final class Mutex {

    #if os(Windows)
        let mutex: UnsafeMutablePointer<SRWLOCK>
    #else
        let mutex: UnsafeMutablePointer<pthread_mutex_t>
    #endif

    /// Initialises an instance of the `Mutex` type
    init() {
        mutex = UnsafeMutablePointer.allocate(capacity: 1)
        #if os(Windows)
            InitializeSRWLock(mutex)
        #else

            mutex.initialize(to: pthread_mutex_t())
            var mutexAttr: pthread_mutexattr_t = pthread_mutexattr_t()
            pthread_mutexattr_settype(&mutexAttr, .init(PTHREAD_MUTEX_ERRORCHECK))
            pthread_mutexattr_init(&mutexAttr)
            let err: Int32 = pthread_mutex_init(mutex, &mutexAttr)
            precondition(err == 0, "Couldn't initialize pthread_mutex due to \(err)")
        #endif
    }

    deinit {
        #if !os(Windows)
            let err: Int32 = pthread_mutex_destroy(mutex)
            precondition(err == 0, "Couldn't destroy pthread_mutex due to \(err)")
        #endif
        mutex.deallocate()
    }

    /// Acquires the lock.
    func lock() {
        #if os(Windows)
            AcquireSRWLockExclusive(mutex)
        #else
            let err: Int32 = pthread_mutex_lock(mutex)
            precondition(err == 0, "\(#function) failed due to \(err)")
        #endif
    }

    /// Releases the lock.
    /// Warning: Only call this method on the same thread that acquired the lock
    /// the mutex
    func unlock() {
        #if os(Windows)
            ReleaseSRWLockExclusive(mutex)
        #else
            let err: Int32 = pthread_mutex_unlock(mutex)
            precondition(err == 0, "\(#function) failed due to \(err)")
        #endif
    }

    /// Checks for lock availability and tries to acquire the lock
    /// - Returns: returns true if lock was acquired successfully, otherwise false
    func tryLock() -> Bool {
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
    @inlinable
    func whileLockedVoid(_ body: () throws -> Void) rethrows {
        lock()
        defer {
            unlock()
        }
        return try body()
    }
}
