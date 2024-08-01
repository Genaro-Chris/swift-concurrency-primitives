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
///     channel <- getInt()
/// }
/// 
/// // do other work
/// if let value = <-channel {
///    print("Got \(value)")
/// }
/// ```
public struct OneShotChannel<Element> {

    private let storage: SingleItemStorage<Element>

    let mutex: Mutex

    let condition: Condition

    /// Initializes an instance of `OneShotChannel` type
    public init() {
        storage = SingleItemStorage()
        mutex = Mutex()
        condition = Condition()
    }

    public func enqueue(item: Element) -> Bool {
        mutex.whileLocked {
            guard !storage.receive else {
                return false
            }
            guard !storage.closed else {
                return false
            }
            storage.value = item
            storage.receive = true
            condition.signal()
            return true
        }

    }

    public func dequeue() -> Element? {
        return mutex.whileLocked {
            condition.wait(mutex: mutex, condition: storage.receive || storage.closed)
            let result: Element? = storage.value
            storage.value = nil
            return result
        }

    }

    public func clear() {
        mutex.whileLockedVoid {
            storage.value = nil
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
            switch storage.value {
            case .none: return 0
            case .some: return 1
            }
        }
    }

    public var isEmpty: Bool {
        return mutex.whileLocked {
            switch storage.value {
            case .none: return true
            case .some: return false
            }
        }
    }
}

extension OneShotChannel: Channel {}
