/// A synchronization primitive which provides a way of executing code exactly once
///  per process or run a one-time global initialization.
///
/// It is similar to Go's [sync.Once](https://pkg.go.dev/sync#Once)
/// or Rust's [std::sync::Once](https://doc.rust-lang.org/std/sync/struct.Once.html) types
///
/// # Example
///
/// ```swift
/// Once.runOnce {
///     // some global initialization work
/// }
/// ```
public enum Once {

    static let done: Locked<Bool> = Locked(initialValue: false)

    /// Runs only once per process no matter how many these times it was called
    /// - Parameter body: a closure is to be exexcuted
    public static func runOnce(_ body: () throws -> Void) rethrows {
        return try done.updateWhileLocked { executed in
            guard !executed else {
                return
            }
            executed = true
            try body()
        }
    }
}
