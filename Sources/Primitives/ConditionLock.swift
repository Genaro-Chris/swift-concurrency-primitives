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

final class ConditionLock {

    let condition: UnsafeMutablePointer<ConditionType>
    let mutex: UnsafeMutablePointer<MutexType>

    init() {
        condition = UnsafeMutablePointer.allocate(capacity: 1)
        mutex = UnsafeMutablePointer.allocate(capacity: 1)

        #if os(Windows)
            InitializeConditionVariable(condition)
            InitializeSRWLock(mutex)
        #else
            var err: Int32 = 0

            condition.initialize(to: pthread_cond_t())
            mutex.initialize(to: pthread_mutex_t())

            err = pthread_cond_init(condition, nil)
            precondition(err == 0, "Couldn't initialise pthread_cond due to \(err)")

            err = pthread_mutex_init(mutex, nil)
            precondition(err == 0, "Couldn't initialise pthread_mutex due to \(err)")
        #endif
    }

    deinit {
        #if !os(Windows)
            var err: Int32 = 0
            err = pthread_cond_destroy(condition)
            precondition(err == 0, "Couldn't destroy pthread_cond due to \(err)")

            err = pthread_mutex_destroy(mutex)
            precondition(err == 0, "Couldn't destroy pthread_mutex due to \(err)")
        #endif

        condition.deallocate()
        mutex.deallocate()
    }

    func lock() {
        #if os(Windows)
            AcquireSRWLockExclusive(mutex)
        #else
            let err: Int32 = pthread_mutex_lock(mutex)
            precondition(err == 0, "\(#function) failed due to \(err)")
        #endif
    }

    func unlock() {
        #if os(Windows)
            ReleaseSRWLockExclusive(mutex)
        #else
            let err: Int32 = pthread_mutex_unlock(mutex)
            precondition(err == 0, "\(#function) failed due to \(err)")
        #endif
    }

    func signal() {
        #if os(Windows)
            WakeConditionVariable(condition)
        #else
            pthread_cond_signal(condition)
        #endif
    }

    func broadcast() {
        #if os(Windows)
            WakeAllConditionVariable(condition)
        #else
            let err: Int32 = pthread_cond_broadcast(condition)
            precondition(err == 0, "\(#function) failed due to \(err)")
        #endif
    }

    func whileLocked<V>(_ body: () throws -> V) rethrows -> V {
        lock()
        defer {
            unlock()
        }
        return try body()
    }

    func wait(for body: @autoclosure () -> Bool) {
        while !body() {
            #if os(Windows)
                let result: Bool = SleepConditionVariableSRW(condition, mutex, INFINITE, 0)
                precondition(
                    result,
                    "\(#function) failed in SleepConditionVariableSRW with error \(GetLastError())"
                )
            #else
                let err: Int32 = pthread_cond_wait(condition, mutex)
                precondition(err == 0, "\(#function) failed due to \(err)")
            #endif
        }
    }

    func wait(until body: @autoclosure () -> Bool) {
        while body() {
            #if os(Windows)
                let result: Bool = SleepConditionVariableSRW(condition, mutex, INFINITE, 0)
                precondition(
                    result,
                    "\(#function) failed in SleepConditionVariableSRW with error \(GetLastError())"
                )
            #else
                let err: Int32 = pthread_cond_wait(condition, mutex)
                precondition(err == 0, "\(#function) failed due to \(err)")
            #endif
        }
    }

    func wait(timeout: TimeDuration) {
        precondition(
            timeout.timeInNano >= 0,
            "time passed in as argument must be greater than or equal to zero")

        #if os(Windows)

            var dwMilliseconds: DWORD = DWORD(timeout.timeInMilli)
            while true {
                let dwWaitStart: DWORD = timeGetTime()
                if !SleepConditionVariableSRW(condition, mutex, dwMilliseconds, 0) {
                    let dwError = GetLastError()
                    if dwError == ERROR_TIMEOUT {
                        return
                    }
                    fatalError("SleepConditionVariableSRW: \(dwError)")
                }

                // NOTE: this may be a spurious wakeup, adjust the timeout accordingly
                dwMilliseconds -= (timeGetTime() - dwWaitStart)
                if dwMilliseconds == 0 { return }
            }
        #else

            var timeoutAbs: timespec = getTimeSpec(with: timeout)

            while true {
                // wait until the time passed as argument as elapsed
                switch pthread_cond_timedwait(condition, mutex, &timeoutAbs) {
                case 0: continue
                case ETIMEDOUT: return
                case let err: fatalError("caught error \(err) while calling pthread_cond_timedwait")
                }
            }
        #endif
    }
}
