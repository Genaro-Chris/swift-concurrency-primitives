import Foundation

/// A buffered blocking threadsafe construct for multithreaded execution context
///  which serves as a communication mechanism between two or more threads
///
/// A fixed size buffer channel which means at any given time it can only contain a certain number of items in it, it
/// blocks on the sender's side if the buffer is full
///
/// This is a multi-producer single-consumer concurrency primitives
/// where they are usually multiple senders and only one receiver useful for
/// message passing
@_spi(OtherChannels)
public struct BoundedChannel<Element> {

    final class Storage {

        var buffer: Deque<Element>

        let capacity: Int

        var send: Bool

        var receive: Bool

        var bufferCount: Int

        var closed: Bool

        init(capacity: Int) {
            self.capacity = capacity
            buffer = Deque(minCapacity: capacity)
            send = true
            receive = false
            bufferCount = 0
            closed = false
        }

        var count: Int {
            buffer.count
        }

        var isEmpty: Bool {
            buffer.isEmpty
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

    let sendCondition: Condition

    let receiveCondition: Condition

    let mutex: Mutex

    /// Buffer size
    ///
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
            fatalError("Cannot initialize this channel with capacity of 0")
        }
        storage = Storage(capacity: size)
        sendCondition = Condition()
        receiveCondition = Condition()
        mutex = Mutex()
    }

    #if compiler(>=5.7) || swift(>=5.7)
        @available(
            *, noasync,
            message:
                "This function blocks the calling thread and therefore shouldn't be called from an async context"
        )
    #endif
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
            storage.enqueue(item)
            storage.receive = true
            receiveCondition.signal()
            return true
        }
    }

    #if compiler(>=5.7) || swift(>=5.7)
        @available(
            *, noasync,
            message:
                "This function blocks the calling thread and therefore shouldn't be called from an async context"
        )
    #endif
    public func dequeue() -> Element? {
        return mutex.whileLocked {
            guard !storage.closed else {
                return storage.dequeue()
            }
            receiveCondition.wait(mutex: mutex, condition: storage.receiveReady)
            storage.bufferCount -= 1
            if storage.bufferCount == 0 {
                storage.receive = false
            }
            storage.send = true
            sendCondition.signal()
            return storage.dequeue()
        }
    }

    public func clear() {
        mutex.whileLocked {
            storage.clear()
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

extension BoundedChannel: IteratorProtocol, Sequence {

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
            storage.count
        }
    }

    public var isEmpty: Bool {
        storage.isEmpty
    }
}

extension BoundedChannel: Channel {}
