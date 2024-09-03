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

    let storageLock: ConditionalLockBuffer<ArrayStorage<Element>>

    /// Initialises an instance of `UnboundedChannel` type
    public init() {
        storageLock = ConditionalLockBuffer.create(value: ArrayStorage(capacity: 0))
    }

    public func enqueue(item: Element) -> Bool {
        return storageLock.interactWhileLocked { storage, conditionLock in
            guard !storage.closed else {
                return false
            }
            storage.enqueue(item)
            if !storage.receive {
                storage.receive = true
            }
            conditionLock.signal()
            return true
        }
    }

    public func dequeue() -> Element? {
        storageLock.interactWhileLocked { storage, conditionLock in
            guard !storage.closed else {
                return storage.dequeue()
            }
            conditionLock.wait(for: storage.receive || storage.closed)
            let result: Element? = storage.dequeue()
            if storage.isEmpty {
                storage.receive = false
            }
            return result
        }
    }

    public func tryDequeue() -> Element? {
        storageLock.interactWhileLocked { storage, conditionLock in
            guard !storage.closed else {
                return storage.dequeue()
            }
            let result: Element? = storage.dequeue()
            if storage.isEmpty {
                storage.receive = false
            }
            return result
        }
    }

    public func clear() {
        storageLock.interactWhileLocked { storage, _ in storage.clear() }
    }

    public func close() {
        storageLock.interactWhileLocked { storage, conditionLock in
            storage.closed = true
            conditionLock.broadcast()
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
        return storageLock.interactWhileLocked { storage, _ in
            storage.closed
        }
    }

    public var count: Int {
        return storageLock.interactWhileLocked { storage, _ in storage.count }
    }

    public var isEmpty: Bool {
        return storageLock.interactWhileLocked { storage, _ in storage.isEmpty }
    }
}

extension UnboundedChannel: Channel {}
