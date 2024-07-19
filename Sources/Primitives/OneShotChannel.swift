import Foundation

/// A single use blocking threadsafe construct for multithreaded execution context which serves
/// as a communication mechanism between two threads
///
/// This is useful in scenarios where a developer needs to send just a value safely across
/// multithreaded context
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
///     channel <- getIntAsync()
/// }
/// // do other work
/// if let value = <-channel {
///    print("Got \(value)")
/// }
/// ```
public struct OneShotChannel<Element> {

    private let storage: Storage<Element>

    let mutex: Mutex

    let condition: Condition

    /// Initializes an instance of `OneShotChannel` type
    public init() {
        storage = Storage(nil)
        mutex = Mutex()
        condition = Condition()
    }

    public func enqueue(item: Element) -> Bool {
        mutex.whileLocked {
            guard !storage.ready else {
                return false
            }
            guard !storage.closed else {
                return false
            }
            storage.buffer = item
            storage.ready = true
            condition.signal()
            return true
        }

    }

    public func dequeue() -> Element? {
        return mutex.whileLocked {
            condition.wait(mutex: mutex, condition: storage.ready || storage.closed)
            let result: Element? = storage.buffer
            storage.buffer = nil
            return result
        }

    }

    public func clear() {
        mutex.whileLockedVoid {
            storage.buffer = nil
        }

    }

    public func close() {
        mutex.whileLockedVoid {
            guard !storage.closed else {
                return
            }
            storage.closed = true
            condition.broadcast()
        }
    }
}

extension OneShotChannel: IteratorProtocol, Sequence {

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

private final class Storage<Element> {

    var buffer: Element?

    var ready: Bool

    var closed: Bool

    init(_ value: Element? = nil) {
        buffer = value
        ready = false
        closed = false
    }
}
