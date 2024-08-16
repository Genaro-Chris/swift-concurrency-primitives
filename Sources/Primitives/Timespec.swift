#if !os(Windows)

    #if canImport(Darwin)
        import Darwin
    #elseif canImport(Glibc)
        import Glibc
    #elseif canImport(Musl)
        import Musl
    #else
        #error("Unable to identify your underlying C library.")
    #endif

    // helps convert seconds into nanoseconds
    let nanoToSecs: Int = 1_000_000_000

    func getTimeSpec(with timeout: TimeDuration) -> timespec {

        let timeoutAbs: timespec
        let allNanoSecs: Int

        #if canImport(Darwin) || os(macOS)

            // get the current time
            var currentTime: timeval = timeval()
            gettimeofday(&currentTime, nil)

            // convert into nanoseconds
            allNanoSecs = timeout.timeInNano + (Int(currentTime.tv_usec) * 1000)

            // calculate the timespec from the argument passed
            timeoutAbs = timespec(
                tv_sec: currentTime.tv_sec + (allNanoSecs / nanoToSecs),
                tv_nsec: allNanoSecs % nanoToSecs)

        #elseif os(Linux) || canImport(Musl) || canImport(Glibc)

            // get the current time
            var currentTime: timespec = timespec(tv_sec: 0, tv_nsec: 0)
            clock_gettime(CLOCK_REALTIME, &currentTime)

            // convert into nanoseconds
            allNanoSecs = timeout.timeInNano + Int(currentTime.tv_nsec)

            // calculate the timespec from the argument passed
            timeoutAbs = timespec(
                tv_sec: currentTime.tv_sec + (allNanoSecs / nanoToSecs),
                tv_nsec: allNanoSecs % nanoToSecs
            )

        #endif

        assert(timeoutAbs.tv_nsec >= 0 && timeoutAbs.tv_nsec < nanoToSecs)
        assert(timeoutAbs.tv_sec >= currentTime.tv_sec)

        return timeoutAbs
    }
#endif
