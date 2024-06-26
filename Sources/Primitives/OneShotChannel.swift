import Atomics
import Foundation

/// A single use blocking threadsafe construct for multithreaded execution context which serves
/// as a communication mechanism between two threads
///
/// This is useful in scenarios where a developer needs to send just a value safely across
/// miltithreaded context
///
/// # Example
///
/// ```swift
/// func getInt() -> Int {
///     // perform some operation
///     return Int.random(in: 0 ... 1000)
/// }
///
/// let channel = OneShotChannel<Int>()
/// DispatchQueue.global() {
///     channel <- (await getIntAsync())
/// }
/// // do other work
/// if let value = <-channel {
///    print("Got \(value)")
/// }
/// ```
@frozen
@_eagerMove
public struct OneShotChannel<Element> {

    @usableFromInline final class _Storage<Value> {

        var buffer: Value

        var readyToReceive: Bool

        var closed: Bool

        init(_ value: Value) {
            buffer = value
            readyToReceive = false
            closed = false
        }
    }

    let mutex: Mutex

    let condition: Condition

    let storage: _Storage<Element?>

    /// Initializes an instance of `OneShotChannel` type
    public init() {
        storage = _Storage(nil)
        mutex = Mutex()
        condition = Condition()
    }

    public func enqueue(_ item: Element) -> Bool {
        mutex.whileLocked {
            guard !storage.readyToReceive else {
                return false
            }
            guard !storage.closed else {
                return false
            }
            storage.buffer = item
            storage.readyToReceive = true
            condition.signal()
            return true
        }

    }

    public func dequeue() -> Element? {
        return mutex.whileLocked {
            condition.wait(mutex: mutex, condition: storage.readyToReceive || storage.closed)
            let result = storage.buffer
            storage.buffer = nil
            return result
        }

    }

    public func clear() {
        mutex.whileLocked {
            storage.buffer = nil
        }

    }

    public func close() {
        mutex.whileLocked {
            storage.closed = true
            condition.broadcast()
        }
    }
}

extension OneShotChannel {

    public mutating func next() -> Element? {
        return dequeue()
    }

}

extension OneShotChannel {

    public var isClosed: Bool {
        return mutex.whileLocked { storage.closed }
    }

    public var length: Int {
        return mutex.whileLocked {
            switch storage.buffer {
            case .none: return 0
            case .some: return 1
            }
        }
    }

    public var isEmpty: Bool {
        return mutex.whileLocked {
            switch storage.buffer {
            case .none: return true
            case .some: return false
            }
        }
    }
}

extension OneShotChannel: Channel {}
