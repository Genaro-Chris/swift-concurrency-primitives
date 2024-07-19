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

    private let storage: Storage<Element>

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
        guard size >= 1 else {
            fatalError("Cannot initialize this channel with capacity less than 1")
        }
        storage = Storage(capacity: size)
        sendCondition = Condition()
        receiveCondition = Condition()
        mutex = Mutex()
    }

    public func enqueue(item: Element) -> Bool {
        return mutex.whileLocked {
            guard !storage.closed else {
                return false
            }
            sendCondition.wait(mutex: mutex, condition: storage.send || storage.closed)
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

    public func dequeue() -> Element? {
        return mutex.whileLocked {
            guard !storage.closed else {
                return storage.dequeue()
            }
            receiveCondition.wait(mutex: mutex, condition: storage.receive || storage.closed)
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
        mutex.whileLockedVoid {
            storage.clear()
        }
    }

    public func close() {
        mutex.whileLockedVoid {
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
        return mutex.whileLocked {
            storage.isEmpty
        }
    }
}

extension BoundedChannel: Channel {}

private final class Storage<Element> {

    var buffer: ContiguousArray<Element>

    let capacity: Int

    var bufferCount: Int

    var send: Bool

    var receive: Bool

    var closed: Bool

    init(capacity: Int) {
        self.capacity = capacity
        buffer = ContiguousArray()
        buffer.reserveCapacity(capacity)
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
