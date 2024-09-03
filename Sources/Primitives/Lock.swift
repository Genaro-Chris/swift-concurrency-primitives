import Foundation

/// `Lock` is concurrency primitive construct that provides mutual exclusion useful for
/// critical section of running code from concurrent accesses
///
/// This `Lock` type will try to acquire the lock and if acquired will block other threads waiting for the lock
/// to become available before proceeding it's execution.
///
/// This provides an abstraction over the underlying mutex for each system
///
/// Note: This is not a recursive lock
///
/// # Example
///
/// ```swift
/// struct Person {
///     var name: String
///     var age: Int
/// }
///
/// class Class {
///     var teacher: Person
///     var students: [Person]
///
///     init(teacher: Person) {
///         self.teacher = teacher
///         students = []
///     }
///
///     func registerStudent(student: Person) {
///         students.append(student)
///     }
/// }
///
/// let scienceClass = Class(teacher: Person(name: "Dr Richard Sven", age: 47))
/// let lock = Lock()
/// let students = [
///     Person(name: "Steven", age: 21), .init(name: "Gwen", age: 22),
///     .init(name: "Oliver", age: 25), .init(name: "Tracy", age: 20),
/// ]
/// for student in students {
///     DispatchQueue.global().async {
///         lock.whileLocked {
///             scienceClass.registerStudent(student: student)
///         }
///     }
/// }
///
/// lock.whileLocked {
///     scienceClass.students.forEach { print($0) }
/// }
/// ```
///
public struct Lock {

    let lock: Mutex

    /// Initialises an instance of the `Lock` type
    public init() {
        lock = Mutex()
    }

    /// Tries to acquire the lock for the duration for the closure passed as
    /// argument and releases the lock immediately after the closure has finished
    /// its execution regardless of how it finishes
    ///
    /// - Parameter body: closure to be executed while being protected by the lock
    /// - Returns: value returned from the closure passed as argument
    ///
    /// # Warning
    /// Avoid calling long running or blocking code while using this function
    public func whileLocked<T>(_ body: () throws -> T) rethrows -> T {
        return try lock.whileLocked(body)
    }

}

extension Lock: @unchecked Sendable {}
