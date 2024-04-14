import Atomics
import Foundation

/// An unbounded blocking threadsafe construct for multithreaded execution context which serves
/// as a communication mechanism between two or more threads
///
/// This means that it has an infinite sized buffer for storing enqueued items
/// in it. This also doesn't provide any form of synchronization between enqueueing and
/// dequeuing items unlike the remaining kinds of ``Channel`` types
@frozen
@_eagerMove
public struct UnboundedChannel<Element> {

    @usableFromInline final class _Storage<Value> {

        let buffer: Buffer<Value>

        var closed: Bool

        var ready: Bool

        init() {
            buffer = Buffer()
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
    }

    let storage: _Storage<Element>

    let mutex: Mutex

    let condition: Condition

    /// Initializes an instance of `UnboundedChannel` type
    public init() {
        storage = _Storage()
        mutex = Mutex()
        condition = Condition()
    }

    public func enqueue(_ item: Element) -> Bool {
        return mutex.whileLocked {
            guard !storage.closed else {
                return false
            }
            storage.buffer.enqueue(item)
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
                return storage.buffer.dequeue()
            }
            condition.wait(mutex: mutex, condition: storage.readyToReceive)
            let result = storage.buffer.dequeue()
            if storage.buffer.isEmpty {
                storage.ready = false
            }
            return result
        }
    }

    public func clear() {
        mutex.whileLocked { storage.buffer.clear() }
    }

    public func close() {
        mutex.whileLocked {
            storage.closed = true
            condition.broadcast()
        }
    }
}

extension UnboundedChannel {

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
        return mutex.whileLocked { storage.buffer.count }
    }

    public var isEmpty: Bool {
        return mutex.whileLocked { storage.buffer.isEmpty }
    }
}

extension UnboundedChannel: Channel {}
