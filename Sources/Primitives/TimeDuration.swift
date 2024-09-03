/// A representation of time.
public struct TimeDuration {
    enum Duration {
        case nanoseconds
        case microseconds
        case milliseconds
        case seconds
        case minutes
    }

    let value: Double

    let duration: Duration

    init(duration: Duration, value: Double) {
        self.duration = duration
        self.value = value
    }

    public static let nanoseconds = { (value: Double) -> TimeDuration in
        TimeDuration(duration: .nanoseconds, value: value)
    }

    public static let microseconds = { (value: Double) -> TimeDuration in
        TimeDuration(duration: .microseconds, value: value)
    }

    public static let milliseconds = { (value: Double) -> TimeDuration in
        TimeDuration(duration: .milliseconds, value: value)
    }

    public static let seconds = { (value: Double) -> TimeDuration in
        TimeDuration(duration: .seconds, value: value)
    }

    public static let minutes = { (value: Double) -> TimeDuration in
        TimeDuration(duration: .minutes, value: value)
    }
}

extension TimeDuration {

    /// Converts current time duration into nanoseconds
    var timeInNano: Int {
        switch self.duration {
        case .nanoseconds: return Int(value)
        case .microseconds: return Int(value * 1_000)
        case .milliseconds: return Int(value * 1_000_000)
        case .seconds: return Int(value * 1_000_000_000)
        case .minutes: return Int(value * 60_000_000_000)
        }
    }
}

extension TimeDuration {

    /// Converts current time duration into milliseconds
    var timeInMilli: Double {
        switch self.duration {
        case .nanoseconds: return value / 1_000_000
        case .microseconds: return value / 1_000
        case .milliseconds: return value
        case .seconds: return value * 1_000
        case .minutes: return value * 60_000
        }
    }
}
