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

    final class Storage {

        var buffer: ContiguousArray<Element>

        var count: Int {
            buffer.count
        }

        var isEmpty: Bool {
            buffer.isEmpty
        }

        var closed: Bool

        var ready: Bool

        init() {
            buffer = ContiguousArray()
            closed = false
            ready = false
        }

        var readyToReceive: Bool {
            switch (ready, closed) {
            case (true, true): return true
            case (true, false): return true
            case (false, true): return true
            case (false, false): return false
            }
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

    let storage: Storage

    let mutex: Mutex

    let condition: Condition

    /// Initializes an instance of `UnboundedChannel` type
    public init() {
        storage = Storage()
        mutex = Mutex()
        condition = Condition()
    }

    public func enqueue(_ item: Element) -> Bool {
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
            condition.wait(mutex: mutex, condition: storage.readyToReceive)
            let result = storage.dequeue()
            if storage.isEmpty {
                storage.ready = false
            }
            return result
        }
    }

    public func clear() {
        mutex.whileLocked { storage.clear() }
    }

    public func close() {
        mutex.whileLocked {
            storage.closed = true
            condition.signal()
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
