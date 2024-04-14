import Atomics
import Foundation

/// A buffered blocking threadsafe construct for multithreaded execution context
///  which serves as a communication mechanism between two or more threads
///
/// A fixed size buffer channel which means at any given time it can only contain a certain number of items in it, it
/// blocks on the sender's side if the buffer has reached that certain number
@_spi(OtherChannels)
@frozen
@_eagerMove
public struct BoundedChannel<Element> {

    @usableFromInline final class _Storage<Value> {

        let capacity: Int

        let buffer: Buffer<Value>

        var send: Bool

        var receive: Bool

        var bufferCount: Int

        var closed: Bool

        init(capacity: Int) {
            self.capacity = capacity
            buffer = Buffer<Value>()
            send = true
            receive = false
            bufferCount = 0
            closed = false
        }

        var receiveReady: Bool {
            switch (receive, closed) {
            case (true, true): return true

            case (true, false): return true

            case (false, true): return true

            case (false, false): return false
            }
        }

        var sendReady: Bool {
            switch (send, closed) {
            case (true, true): return true

            case (true, false): return true

            case (false, true): return true

            case (false, false): return false
            }
        }
    }

    let storage: _Storage<Element>

    let sendCondition: Condition

    let receiveCondition: Condition

    let mutex: Mutex

    /// Maximum number of stored items at any given time
    public var capacity: Int {
        mutex.whileLocked {
            storage.capacity
        }
    }

    /// Initializes an instance of `BoundedChannel` type
    /// - Parameter size: maximum capacity of the channel
    /// - Returns: nil if the `size` argument is less than one
    public init(size: Int) {
        guard size > 0 else {
            preconditionFailure("Cannot initialize this channel with capacity of 0")
        }
        storage = _Storage(capacity: size)
        sendCondition = Condition()
        receiveCondition = Condition()
        mutex = Mutex()
    }

    public func enqueue(_ item: Element) -> Bool {
        return mutex.whileLocked {
            guard !storage.closed else {
                return false
            }
            sendCondition.wait(mutex: mutex, condition: storage.sendReady)
            guard !storage.closed else {
                return false
            }
            storage.bufferCount += 1
            if storage.bufferCount == storage.capacity {
                storage.send = false
            }
            storage.buffer.enqueue(item)
            storage.receive = true
            receiveCondition.signal()
            return true
        }
    }

    public func dequeue() -> Element? {
        return mutex.whileLocked {
            guard !storage.closed else {
                return storage.buffer.dequeue()
            }
            receiveCondition.wait(mutex: mutex, condition: storage.receiveReady)
            storage.bufferCount -= 1
            if storage.bufferCount == 0 {
                storage.receive = false
            }
            storage.send = true
            sendCondition.signal()
            return storage.buffer.dequeue()
        }
    }

    public func clear() {
        mutex.whileLocked {
            storage.buffer.clear()
        }
    }

    public func close() {
        mutex.whileLocked {
            storage.closed = true
            sendCondition.broadcast()
            receiveCondition.broadcast()
        }
    }
}

extension BoundedChannel {

    public mutating func next() -> Element? {
        return dequeue()
    }

}

extension BoundedChannel {

    public var isClosed: Bool {
        return mutex.whileLocked { storage.closed }
    }

    public var length: Int {
        return mutex.whileLocked {
            storage.buffer.count
        }
    }

    public var isEmpty: Bool {
        storage.buffer.isEmpty
    }
}

extension BoundedChannel: Channel {}
