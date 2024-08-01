/// This acts as a mutual exclusion primitive useful for protecting shared data
///
/// This `Locked` type will try to acquire the lock and if acquired will block other threads waiting for the lock,
/// later releasing the lock to become available for other threads
///
/// Each `Locked` type has a generic type parameter which represents the data that it is protecting.
/// The data can be accessed through in the following ways:
/// - the ``updateWhileLocked(_:)`` which guarantees that the data is only ever accessed when the lock is acquired
/// - the inner type instance properties through dynamic member lookup
/// 
/// This `Locked` type is also a property wrapper which means it can be created
/// easily and it provides a projected value which can be easily
/// used to update the value.
///
/// Note: This is not a recursive lock
///
/// # Examples
/// a) Using the property wrapper
///
/// ```swift
/// struct Student {
///     var age: Int
///     var scores: [Int]
/// }
///
/// @Locked var student = Student(age: 0, scores: [])
/// DispatchQueue.concurrentPerform(iterations: 10) { index in
///     $student.updateWhileLocked { student in
///         student.scores.append(index)
///     }
///     if index == 9 {
///         $student.age = 18
///     }
/// }
/// assert(student.scores.count == 10)
/// assert(student.age == 18)
/// ```
///
/// b) Using the Locked type
///
/// ```swift
/// struct Student {
///     var age: Int
///     var scores: [Int]
/// }
///
/// var student = Locked(Student(age: 0, scores: []))
/// DispatchQueue.concurrentPerform(iterations: 10) { index in
///     student.updateWhileLocked { student in
///         student.scores.append(index)
///     }
///     if index == 9 {
///         student.age = 18
///     }
/// }
/// assert(student.scores.count == 10)
/// assert(student.age == 18)
/// ```
///
@propertyWrapper
@dynamicMemberLookup
public final class Locked<Element> {

    let lock: Lock

    var value: Element

    /// The value which can be accessed safely in multithreaded context
    public var wrappedValue: Element {
        get {
            return lock.whileLocked { value }
        }
        set {
            lock.whileLockedVoid { value = newValue }
        }
    }

    /// Initialises an instance of the `Locker` type with a value to be protected
    public init(initialValue: Element) {
        lock = Lock()
        value = initialValue
    }

    /// Initialises an instance of the `Locker` type with a value to be protected
    convenience public init(wrappedValue value: Element) {
        self.init(initialValue: value)
    }

    /// An instance of Locked type
    public var projectedValue: Locked<Element> {
        return self
    }

    /// This function will block the current thread until it acquires the lock.
    /// Upon acquiring the lock, only this thread can access or update the value stored in this type.
    /// - Parameter using: a closure that updates or changes the value stored in this type
    /// - Returns: value returned from the closure passed as argument
    ///
    /// # Warning
    /// Avoid calling long running or blocking code while using this function
    public func updateWhileLocked<T>(_ mutateWith: (inout Element) throws -> T) rethrows -> T {
        return try lock.whileLocked {
            return try mutateWith(&value)
        }
    }

    /// This function will block the current thread until it acquires the lock.
    /// Upon acquiring the lock, only this thread can access or update the value stored in this type.
    /// - Parameter using: a closure that updates or changes the value stored in this type
    /// - Returns: value returned from the closure passed as argument
    ///
    /// # Warning
    /// Avoid calling long running or blocking code while using this function
    public func updateWhileLocked(_ mutateWith: (inout Element) throws -> Void) rethrows -> Void {
        return try lock.whileLocked {
            return try mutateWith(&value)
        }
    }
}

extension Locked {

    public subscript<T>(dynamicMember memberKeyPath: KeyPath<Element, T>) -> T {
        updateWhileLocked { $0[keyPath: memberKeyPath] }
    }
}
