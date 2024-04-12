/// A representation of time.
public enum TimeDuration {
    case nanoseconds(Double)
    case microseconds(Double)
    case milliseconds(Double)
    case seconds(Double)
}

extension TimeDuration {

    /// Converts current time duration into nanoseconds
    var timeInNano: Int64 {
        switch self {
        case let .nanoseconds(time): return Int64(time)

        case let .microseconds(time): return Int64(time * 1_000)

        case let .milliseconds(time): return Int64(time * 1_000_000)

        case let .seconds(time): return Int64(time * 1_000_000_000)

        }
    }
}

extension TimeDuration {

    /// Converts current time duration into milliseconds
    var timeInMilli: Double {
        switch self {
        case let .nanoseconds(time): return time / 1_000_000

        case let .microseconds(time): return time / 1_000

        case let .milliseconds(time): return time

        case let .seconds(time): return time * 1000

        }
    }
}

extension TimeDuration {
    /// Current time
    var time: Double {
        switch self {
        case let .nanoseconds(time): return time

        case let .microseconds(time): return time

        case let .milliseconds(time): return time

        case let .seconds(time): return time

        }
    }
}
