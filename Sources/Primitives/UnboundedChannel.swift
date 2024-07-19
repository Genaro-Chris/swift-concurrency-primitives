import Foundation

/// An unbounded blocking threadsafe construct for multithreaded execution context which serves
/// as a communication mechanism between two or more threads
///
/// This means that it has an infinite sized buffer for storing enqueued items
/// in it. This also doesn't provide any form of synchronization between enqueueing and
/// dequeuing items unlike the remaining kinds of ``Channel`` types
///
/// This is a multi-producer single-consumer concurrency primitives
/// where they are usually multiple senders and only one receiver useful for
/// message passing
public struct UnboundedChannel<Element> {

    private let storage: Storage<Element>

    let mutex: Mutex

    let condition: Condition

    /// Initializes an instance of `UnboundedChannel` type
    public init() {
        storage = Storage()
        mutex = Mutex()
        condition = Condition()
    }

    public func enqueue(item: Element) -> Bool {
        return mutex.whileLocked {
            guard !storage.closed else {
                return false
            }
            storage.enqueue(item)
            if !storage.ready {
                storage.ready = true
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
            condition.wait(mutex: mutex, condition: storage.ready || storage.closed)
            let result: Element? = storage.dequeue()
            if storage.isEmpty {
                storage.ready = false
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

private final class Storage<Element> {

    var buffer: ContiguousArray<Element>

    var closed: Bool

    var ready: Bool

    var count: Int {
        buffer.count
    }

    var isEmpty: Bool {
        buffer.isEmpty
    }

    init() {
        buffer = ContiguousArray()
        closed = false
        ready = false
    }

    func enqueue(_ item: Element) {
        buffer.append(item)
    }

    func dequeue() -> Element? {
        guard !buffer.isEmpty else {
            return nil
        }
        return buffer.removeFirst()
    }

    func clear() {
        buffer.removeAll()
    }
}
