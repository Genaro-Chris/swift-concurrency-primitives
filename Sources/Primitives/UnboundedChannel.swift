import Foundation

/// An unbounded blocking threadsafe construct for multithreaded execution context which serves
/// as a communication mechanism between two or more threads
///
/// This means that it has an infinite sized buffer for storing enqueued items
/// in it. This also doesn't provide any form of synchronization between enqueueing and
/// dequeuing items unlike the other kind of ``Channel`` types
///
/// This is a multi-producer single-consumer concurrency primitives
/// where they are usually multiple senders and only one receiver useful for
/// message passing
public struct UnboundedChannel<Element> {

    private let storage: MultiElementStorage<Element>

    let mutex: Mutex

    let condition: Condition

    /// Initializes an instance of `UnboundedChannel` type
    public init() {
        storage = MultiElementStorage()
        mutex = Mutex()
        condition = Condition()
    }

    public func enqueue(item: Element) -> Bool {
        return mutex.whileLocked {
            guard !storage.closed else {
                return false
            }
            storage.enqueue(item)
            if !storage.receive {
                storage.receive = true
            }
            condition.signal()
            return true
        }
    }

    public func dequeue() -> Element? {
        mutex.whileLocked {
            guard !storage.closed else {
                return storage.dequeue()
            }
            condition.wait(mutex: mutex, condition: storage.receive || storage.closed)
            let result: Element? = storage.dequeue()
            if storage.isEmpty {
                storage.receive = false
            }
            return result
        }
    }

    public func clear() {
        mutex.whileLockedVoid { storage.clear() }
    }

    public func close() {
        mutex.whileLockedVoid {
            storage.closed = true
            condition.broadcast()
        }
    }
}

extension UnboundedChannel: IteratorProtocol, Sequence {

    public mutating func next() -> Element? {
        return dequeue()
    }

}

extension UnboundedChannel {

    public var isClosed: Bool {
        return mutex.whileLocked {
            storage.closed
        }
    }

    public var length: Int {
        return mutex.whileLocked { storage.count }
    }

    public var isEmpty: Bool {
        return mutex.whileLocked { storage.isEmpty }
    }
}

extension UnboundedChannel: Channel {}
