/// A synchronization primitive which provides a way of executing code exactly once
///  per instance
///
/// This is particularly useful for secondary initialization in classes ensuring that the property is
/// fully initialized once no matter times or where it is was called ie in concurrent accesses
///
/// # Example
///
/// ```swift
/// class SomeClass {
///
///    let onceFlag = OnceState()
///
///    var someProperty = SomeProperty()
///
///    func someMethod() {
///        onceFlag.runOnce {
///            someProperty.activate()
///        }
///        // use the property here fully initialization and activated
///    }
/// }
/// ```
public struct OnceState {

    let done: Locked<Bool>

    /// Initialises an instance of the `OnceState` type
    public init() {
        done = Locked(false)
    }

    /// Runs only once per instance of `OnceState` type no matter how many these times it was called
    /// - Parameter body: a closure is to be exexcuted
    public func runOnce(body: () throws -> Void) rethrows {
        return try done.updateWhileLocked { value in
            guard !value else {
                return
            }
            value = true
            try body()
        }
    }

    /// Indicates if this instance have executed it's `runOnce` method
    public var hasExecuted: Bool {
        done.updateWhileLocked { $0 }
    }
}
