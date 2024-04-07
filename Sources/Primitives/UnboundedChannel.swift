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

    @usableFromInline struct Storage<Value> {

        @usableFromInline let buffer: Buffer<Value> = Buffer()

        @usableFromInline var closed = false

        @usableFromInline var ready = false

        @usableFromInline var readyToReceive: Bool {
            switch (ready, closed) {
                case (true, true): true
                case (true, false): true
                case (false, true): true
                case (false, false): false
            }
        }
    }

    @usableFromInline let storage: Box<Storage<Element>>

    @usableFromInline let mutex: Mutex

    @usableFromInline let condition: Condition

    /// Initializes an instance of `UnboundedChannel` type
    public init() {
        storage = Box(Storage())
        mutex = Mutex()
        condition = Condition()
    }

    @inlinable
    public func enqueue(_ item: Element) -> Bool {
        return mutex.whileLocked {
            guard !storage.closed else {
                return false
            }
            storage.interact {
                if !$0.ready {
                    $0.ready = true
                }
                $0.buffer.enqueue(item)
                condition.signal()
            }
            return true
        }
    }

    @inlinable
    public func dequeue() -> Element? {
        mutex.whileLocked {
            guard !storage.closed else {
                return storage.interact {
                    return $0.buffer.dequeue()
                }
            }
            condition.wait(mutex: mutex, condition: storage.readyToReceive)
            return storage.interact {
                guard !$0.buffer.isEmpty else {
                    $0.ready = false
                    return nil
                }
                return $0.buffer.dequeue()
            }
        }
    }

    public func clear() {
        mutex.whileLocked { storage.interact { $0.buffer.clear() } }
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
