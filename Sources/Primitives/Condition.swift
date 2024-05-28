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
/// This object provides a safe abstraction on top of a single `pthread_cond_t` on pthread based system
/// or `CONDITION_VARIABLE` on windows system.
///
/// # Note
/// Any attempt to use multiple mutexes on the same condition variable may result in
/// an undefined behaviour at runtime
@_spi(Sync)
public final class Condition {

    #if os(Windows)
        let condition: UnsafeMutablePointer<CONDITION_VARIABLE>
    #else
        let condition: UnsafeMutablePointer<pthread_cond_t>
        let conditionAttr: UnsafeMutablePointer<pthread_condattr_t>
    #endif

    /// Initializes an instance of `Condition` type
    public init() {
        condition = UnsafeMutablePointer.allocate(capacity: 1)
        #if os(Windows)
            InitializeConditionVariable(condition)
        #else
            condition.initialize(to: pthread_cond_t())
            conditionAttr = UnsafeMutablePointer.allocate(capacity: 1)
            conditionAttr.initialize(to: pthread_condattr_t())
            pthread_condattr_init(conditionAttr)
            let err = pthread_cond_init(condition, conditionAttr)
            precondition(err == 0, "Couldn't initialize pthread_cond due to \(err)")
        #endif

    }

    deinit {
        #if os(Windows)
            // Windows condition variables do not need to be explicitly destroyed
        #else
            pthread_condattr_destroy(conditionAttr)
            conditionAttr.deallocate()
            let err = pthread_cond_destroy(condition)
            precondition(err == 0, "Couldn't destroy pthread_cond due to \(err)")
        #endif
        condition.deallocate()
    }

    /// Blocks the current thread until a specified time interval is reached
    /// - Parameters:
    ///   - mutex: The mutex which this function tries to acquire and lock
    ///   - forTimeInterval: The number of seconds to wait to acquire
    ///     the lock before giving up.
    /// - Returns: `true` if the lock was acquired, `false` if the wait timed out.
    public func wait(mutex: Mutex, timeout: TimeDuration) -> Bool {
        precondition(timeout.time >= 0, "time passed in as argument must be greater than zero")

        // ensure that the mutex is already locked
        precondition(
            !mutex.tryLock(), "\(#function) must be called only while the mutex is locked")

        #if os(Windows)

            var dwMilliseconds: DWORD = DWORD(timeout.timeInMilli)
            while true {
                let dwWaitStart = timeGetTime()
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

            var timeoutAbs = getTimeSpec(with: timeout)

            // wait until the time passed as argument as elapsed
            switch pthread_cond_timedwait(condition, mutex.mutex, &timeoutAbs) {
            case 0: return true
            case ETIMEDOUT: return false
            case let err: fatalError("caught error \(err) while calling pthread_cond_timedwait")
            }
        #endif
    }

    /// Blocks the current thread until the condition becomes true
    /// - Parameters:
    ///   - mutex: The mutex which this function tries to acquire and lock
    ///   - condition: The condition which must later become true
    public func wait(mutex: Mutex, condition body: @autoclosure () -> Bool) {
        // ensure that the mutex is already locked
        precondition(
            !mutex.tryLock(), "\(#function) must be called only while the mutex is locked")

        while true {
            if body() { break }
            #if os(Windows)
                let result = SleepConditionVariableSRW(condition, mutex.mutex, INFINITE, 0)
                precondition(
                    result,
                    "\(#function) failed in SleepConditionVariableSRW with error \(GetLastError())"
                )
            #else
                let err = pthread_cond_wait(condition, mutex.mutex)
                precondition(err == 0, "\(#function) failed due to \(err)")
            #endif
        }
    }

    /// Blocks the current thread
    /// - Parameter mutex: The mutex which this function tries to acquire and lock until a signal or broadcast is made
    public func wait(mutex: Mutex) {
        // ensure that the mutex is already locked
        precondition(
            !mutex.tryLock(), "\(#function) must be called only while the mutex is locked")
        #if os(Windows)
            let result = SleepConditionVariableSRW(condition, mutex.mutex, INFINITE, 0)
            precondition(
                result,
                "\(#function) failed in SleepConditionVariableSRW with error \(GetLastError())"
            )
        #else

            let err = pthread_cond_wait(condition, mutex.mutex)
            precondition(err == 0, "\(#function) failed due to error \(err)")
        #endif
    }

    /// Signals only one thread to wake itself up
    public func signal() {
        #if os(Windows)
            WakeConditionVariable(condition)
        #else
            pthread_cond_signal(condition)
        #endif
    }

    /// Broadcast to all blocked threads to wake up
    public func broadcast() {
        #if os(Windows)
            WakeAllConditionVariable(condition)
        #else
            let err = pthread_cond_broadcast(condition)
            precondition(err == 0, "\(#function) failed due to \(err)")
        #endif
    }

}

#if !os(Windows)
    func getTimeSpec(with timeout: TimeDuration) -> timespec {

        // helps convert seconds into nanoseconds
        let nsecsPerSec: Int = 1_000_000_000

        let timeoutAbs: timespec

        #if canImport(Darwin) || os(macOS)

            // get the current time
            var currentTime: timeval = timeval()
            gettimeofday(&currentTime, nil)

            // convert into nanoseconds
            let allNanoSecs: Int = timeout.timeInNano + (Int(currentTime.tv_usec) * 1000)

            // calculate the timespec from the argument passed
            timeoutAbs = timespec(
                tv_sec: currentTime.tv_sec + (allNanoSecs / nsecsPerSec),
                tv_nsec: allNanoSecs % nsecsPerSec)

            assert(timeoutAbs.tv_nsec >= 0 && timeoutAbs.tv_nsec < nsecsPerSec)
            assert(timeoutAbs.tv_sec >= currentTime.tv_sec)

        #elseif os(Linux)

            // get the current time
            var currentTime: timespec = timespec(tv_sec: 0, tv_nsec: 0)
            clock_gettime(CLOCK_REALTIME, &currentTime)

            // convert into nanoseconds
            let allNanoSecs: Int = timeout.timeInNano + Int(currentTime.tv_nsec)

            // calculate the timespec from the argument passed
            timeoutAbs = timespec(
                tv_sec: currentTime.tv_sec + (allNanoSecs / nsecsPerSec),
                tv_nsec: allNanoSecs % nsecsPerSec
            )

            assert(timeoutAbs.tv_nsec >= 0 && timeoutAbs.tv_nsec < nsecsPerSec)
            assert(timeoutAbs.tv_sec >= currentTime.tv_sec)

        #endif

        return timeoutAbs
    }
#endif
