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

    let storageLock: ConditionalLockBuffer<SingleItemStorage<Element>>

    /// Initialises an instance of `OneShotChannel` type
    public init() {
        storageLock = ConditionalLockBuffer.create(value: SingleItemStorage())
    }

    public func enqueue(item: Element) -> Bool {
        storageLock.interactWhileLocked { storage, conditionLock in
            guard !storage.receive else {
                return false
            }
            guard !storage.closed else {
                return false
            }
            storage.value = item
            storage.receive = true
            conditionLock.signal()
            return true
        }

    }

    public func dequeue() -> Element? {
        return storageLock.interactWhileLocked { storage, conditionLock in
            conditionLock.wait(for: storage.receive || storage.closed)
            let result: Element? = storage.value
            storage.value = nil
            return result
        }
    }

    public func tryDequeue() -> Element? {
        return storageLock.interactWhileLocked { storage, conditionLock in
            let result: Element? = storage.value
            storage.value = nil
            return result
        }

    }

    public func clear() {
        storageLock.interactWhileLocked { storage, _ in
            storage.value = nil
        }

    }

    public func close() {
        storageLock.interactWhileLocked { storage, conditionLock in
            guard !storage.closed else {
                return
            }
            storage.closed = true
            conditionLock.broadcast()
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
        return storageLock.interactWhileLocked { storage, _ in storage.closed }
    }

    public var count: Int {
        return storageLock.interactWhileLocked { storage, _ in
            switch storage.value {
            case .none: return 0
            case .some: return 1
            }
        }
    }

    public var isEmpty: Bool {
        return storageLock.interactWhileLocked { storage, _ in
            switch storage.value {
            case .none: return true
            case .some: return false
            }
        }
    }
}

extension OneShotChannel: Channel {}
