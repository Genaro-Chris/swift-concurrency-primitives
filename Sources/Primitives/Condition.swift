import Atomics

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
    public func wait(mutex: Mutex, timeoutSeconds: Double) -> Bool {
        precondition(timeoutSeconds >= 0, "time passed in as argument must be greater than zero")

        // ensure that the mutex is already locked
        precondition(
            !mutex.tryLock(), "\(#function) must be called only while the mutex is locked")

        #if os(Windows)
            var dwMilliseconds: DWORD = DWORD(timeoutSeconds * 1000)
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
            }
            return true
        #else

            // convert argument passed into nanoseconds
            let nsecPerSec: Int64 = 1_000_000_000
            let timeoutNS = Int64(timeoutSeconds * Double(nsecPerSec))

            // get the current clock id
            var clockID = clockid_t(0)
            pthread_condattr_getclock(conditionAttr, &clockID)

            // get the current time
            var curTime = timespec(tv_sec: 0, tv_nsec: 0)
            clock_gettime(clockID, &curTime)

            // calculate the timespec from the argument passed
            let allNSecs: Int64 = timeoutNS + Int64(curTime.tv_nsec) / nsecPerSec
            var timeoutAbs = timespec(
                tv_sec: curTime.tv_sec + Int(allNSecs / nsecPerSec),
                tv_nsec: curTime.tv_nsec + Int(allNSecs % nsecPerSec)
            )

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

    /// Blocks the current thread until the condition becomes true
    /// - Parameters:
    ///   - mutex: The mutex which this function tries to acquire and lock
    ///   - until: The condition which must later become false
    public func wait(mutex: Mutex, until body: @autoclosure () -> Bool) {
        // ensure that the mutex is already locked
        precondition(
            !mutex.tryLock(), "\(#function) must be called only while the mutex is locked")
        while true {
            if !body() { break }
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

    ///
    public func signal() {
        #if os(Windows)
            WakeConditionVariable(condition)
        #else
            pthread_cond_signal(condition)
        #endif
    }

    ///
    public func broadcast() {
        #if os(Windows)
            WakeAllConditionVariable(condition)
        #else
            let err = pthread_cond_broadcast(condition)
            precondition(err == 0, "\(#function) failed due to \(err)")
        #endif
    }

}
