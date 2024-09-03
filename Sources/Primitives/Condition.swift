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

#if os(Windows)
    typealias ConditionType = CONDITION_VARIABLE
#else
    typealias ConditionType = pthread_cond_t
#endif

/// A Condition Variable type
///
/// Condition variables provides the ability to block a thread in such a way that
/// it consumes no CPU time while waiting for an event to occur.
/// They are typically associated with a boolean predicate
///  (a condition), or time duration and a mutex.
///
/// When a condition variable blockes a thread, it is usually unblocked when the predicate passed as argument changes,
/// a signal or broadcast is received.
///
/// Methods of this class will block the current thread of execution.
///
/// This object provides a safe abstraction on top of a single `pthread_cond_t` on pthread based systems
/// or `CONDITION_VARIABLE` on windows systems.
///
/// # Warning
/// Any attempt to use multiple mutexes on the same condition variable may result in
/// an undefined behaviour at runtime
final class Condition {

    let condition: UnsafeMutablePointer<ConditionType>

    /// Initialises an instance of `Condition` type
    init() {
        condition = UnsafeMutablePointer.allocate(capacity: 1)
        #if os(Windows)
            InitializeConditionVariable(condition)
        #else
            condition.initialize(to: pthread_cond_t())
            let err: Int32 = pthread_cond_init(condition, nil)
            precondition(err == 0, "Couldn't initialise pthread_cond due to \(err)")
        #endif

    }

    deinit {
        #if !os(Windows)
            let err: Int32 = pthread_cond_destroy(condition)
            precondition(err == 0, "Couldn't destroy pthread_cond due to \(err)")
        #endif
        condition.deallocate()
    }

    /// Blocks the current thread until a specified time duration passes
    /// - Parameters:
    ///   - mutex: mutex which this function tries to acquire and lock
    ///   - timeout: time duration to hold the mutex for
    /// - Returns: `true` if the lock was acquired, `false` if the wait timed out.
    func wait(mutex: Mutex, timeout: TimeDuration) -> Bool {
        precondition(
            timeout.timeInNano >= 0,
            "time passed in as argument must be greater than or equal to zero")

        // ensure that the mutex is already locked
        precondition(
            !mutex.tryLock(), "\(#function) must be called only while the mutex is locked")

        #if os(Windows)

            var dwMilliseconds: DWORD = DWORD(timeout.timeInMilli)
            while true {
                let dwWaitStart: DWORD = timeGetTime()
                if !SleepConditionVariableSRW(condition, mutex.mutex, dwMilliseconds, 0) {
                    let dwError = GetLastError()
                    if dwError == ERROR_TIMEOUT {
                        return false
                    }
                    fatalError("SleepConditionVariableSRW: \(dwError)")
                }

                // NOTE: this may be a spurious wakeup, adjust the timeout accordingly
                dwMilliseconds -= (timeGetTime() - dwWaitStart)
                if dwMilliseconds == 0 { return true }
            }
        #else

            var timeoutAbs: timespec = getTimeSpec(with: timeout)

            while true {
                // wait until the time passed as argument as elapsed
                switch pthread_cond_timedwait(condition, mutex.mutex, &timeoutAbs) {
                case 0: continue
                case ETIMEDOUT: return false
                case let err: fatalError("caught error \(err) while calling pthread_cond_timedwait")
                }
            }
        #endif
    }

    /// Blocks the current thread until a specified time duration passes or the condition
    /// becomes true
    /// - Parameters:
    ///   - mutex: mutex which this function tries to acquire and lock
    ///   - for: condition which is false that must later become true
    ///   - timeout: time duration to hold the mutex for
    /// - Returns: `true` if the lock was acquired, `false` if the wait timed out.
    func wait(mutex: Mutex, for body: @autoclosure @escaping () -> Bool, timeout: TimeDuration)
        -> Bool
    {
        precondition(
            timeout.timeInNano >= 0, "time passed in as argument must be greater than zero")

        // ensure that the mutex is already locked
        precondition(
            !mutex.tryLock(), "\(#function) must be called only while the mutex is locked")

        #if os(Windows)

            var dwMilliseconds: DWORD = DWORD(timeout.timeInMilli)
            while true {
                if body() {
                    return true
                }
                let dwWaitStart: DWORD = timeGetTime()
                if !SleepConditionVariableSRW(condition, mutex.mutex, dwMilliseconds, 0) {
                    let dwError = GetLastError()
                    if dwError == ERROR_TIMEOUT {
                        return false
                    }
                    fatalError("SleepConditionVariableSRW: \(dwError)")
                }

                // NOTE: this may be a spurious wakeup, adjust the timeout accordingly
                dwMilliseconds -= (timeGetTime() - dwWaitStart)
                if dwMilliseconds == 0 { return true }
            }
        #else

            var timeoutAbs: timespec = getTimeSpec(with: timeout)

            while true {
                if body() {
                    return true
                }
                // wait until the time passed as argument as elapsed
                switch pthread_cond_timedwait(condition, mutex.mutex, &timeoutAbs) {
                case 0: continue
                case ETIMEDOUT: return false
                case let err: fatalError("caught error \(err) while calling pthread_cond_timedwait")
                }
            }

        #endif
    }

    /// Blocks the current thread until the condition becomes true
    /// - Parameters:
    ///   - mutex: mutex which this function tries to acquire and lock
    ///   - for: condition which is false that must later become true
    ///
    /// Always ensure that when the condition changes, it is followed by either
    /// ``broadcast`` or ``signal`` method
    func wait(mutex: Mutex, for body: @autoclosure () -> Bool) {
        // ensure that the mutex is already locked
        precondition(
            !mutex.tryLock(), "\(#function) must be called only while the mutex is locked")

        while !body() {
            #if os(Windows)
                let result: Bool = SleepConditionVariableSRW(condition, mutex.mutex, INFINITE, 0)
                precondition(
                    result,
                    "\(#function) failed in SleepConditionVariableSRW with error \(GetLastError())"
                )
            #else
                let err: Int32 = pthread_cond_wait(condition, mutex.mutex)
                precondition(err == 0, "\(#function) failed due to \(err)")
            #endif
        }
    }

    /// Blocks the current thread until the condition becomes false
    /// - Parameters:
    ///   - mutex: mutex which this function tries to acquire and lock
    ///   - until: condition which is true that must later become false
    ///
    /// Always ensure that when the condition changes, it is followed by either
    /// ``broadcast`` or ``signal`` method
    func wait(mutex: Mutex, until body: @autoclosure () -> Bool) {
        // ensure that the mutex is already locked
        precondition(
            !mutex.tryLock(), "\(#function) must be called only while the mutex is locked")

        while body() {
            #if os(Windows)
                let result: Bool = SleepConditionVariableSRW(condition, mutex.mutex, INFINITE, 0)
                precondition(
                    result,
                    "\(#function) failed in SleepConditionVariableSRW with error \(GetLastError())"
                )
            #else
                let err: Int32 = pthread_cond_wait(condition, mutex.mutex)
                precondition(err == 0, "\(#function) failed due to \(err)")
            #endif
        }
    }

    /// Blocks the current thread until a signal or broadcast is made
    /// - Parameter mutex: mutex which this function tries to acquire and lock
    func wait(mutex: Mutex) {
        // ensure that the mutex is already locked
        precondition(
            !mutex.tryLock(), "\(#function) must be called only while the mutex is locked")

        #if os(Windows)
            let result: Bool = SleepConditionVariableSRW(condition, mutex.mutex, INFINITE, 0)
            precondition(
                result,
                "\(#function) failed in SleepConditionVariableSRW with error \(GetLastError())"
            )
        #else
            let err: Int32 = pthread_cond_wait(condition, mutex.mutex)
            precondition(err == 0, "\(#function) failed due to error \(err)")
        #endif
    }

    /// Signals only one thread to wake itself up
    ///
    /// # Warning
    /// Highly advised to call this function while the mutex is locked
    func signal() {
        #if os(Windows)
            WakeConditionVariable(condition)
        #else
            pthread_cond_signal(condition)
        #endif
    }

    /// Broadcast to all blocked threads to wake up
    ///
    /// # Warning
    /// Highly advised to call this function while the mutex is locked
    func broadcast() {
        #if os(Windows)
            WakeAllConditionVariable(condition)
        #else
            let err: Int32 = pthread_cond_broadcast(condition)
            precondition(err == 0, "\(#function) failed due to \(err)")
        #endif
    }

}
