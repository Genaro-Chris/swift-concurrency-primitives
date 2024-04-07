import Atomics
import Foundation

/// A buffered blocking threadsafe construct for multithreaded execution context which serves as a communication mechanism between two or more threads
///
/// A fixed size buffer channel which means at any given time it can only contain a certain number of items in it, it
/// blocks on the sender's side if the buffer has reached that certain number
struct BoundedChannel<Element> {

    @usableFromInline struct Storage<Value> {

        init(capacity: Int) {
            self.capacity = capacity
        }

        let capacity: Int

        @usableFromInline let buffer = Buffer<Value>()

        @usableFromInline var send = true

        @usableFromInline var receive = false

        @usableFromInline var bufferCount = 0

        @usableFromInline var closed = false

        @usableFromInline var receiveReady: Bool {
            switch (receive, closed) {
                case (true, true): true

                case (true, false): true

                case (false, true): true

                case (false, false): false
            }
        }

        @usableFromInline var sendReady: Bool {
            switch (send, closed) {
                case (true, true): true

                case (true, false): true

                case (false, true): true

                case (false, false): false
            }
        }
    }

    @usableFromInline let storage: Box<Storage<Element>>

    @usableFromInline let sendCondition: Condition

    @usableFromInline let receiveCondition: Condition

    @usableFromInline let mutex: Mutex

    /// Maximum number of stored items at any given time
    var capacity: Int {
        mutex.whileLocked {
            storage.capacity
        }
    }

    /// Initializes an instance of `BoundedChannel` type
    /// - Parameter size: maximum capacity of the channel
    /// - Returns: nil if the `size` argument is less than one
    init(size: Int) {
        guard size > 0 else {
            preconditionFailure("Cannot initialize this channel with capacity of 0")
        }
        storage = Box(Storage(capacity: size))
        sendCondition = Condition()
        receiveCondition = Condition()
        mutex = Mutex()
    }

    func enqueue(_ item: Element) -> Bool {
        return mutex.whileLocked {
            guard !storage.closed else {
                return false
            }
            sendCondition.wait(mutex: mutex, condition: storage.sendReady)
            guard !storage.closed else {
                return false
            }
            storage.interact {
                $0.bufferCount += 1
                if $0.bufferCount == $0.capacity {
                    $0.send = false
                }
                $0.buffer.enqueue(item)
                $0.receive = true
            }
            receiveCondition.signal()
            return true
        }
    }

    func dequeue() -> Element? {
        return mutex.whileLocked {
            guard !storage.closed else {
                return storage.interact {
                    $0.buffer.dequeue()
                }
            }
            receiveCondition.wait(mutex: mutex, condition: storage.receiveReady)
            return storage.interact {
                $0.bufferCount -= 1
                if $0.bufferCount == 0 {
                    $0.receive = false
                }
                $0.send = true
                sendCondition.signal()
                return $0.buffer.dequeue()
            }
        }
    }

    func clear() {
        mutex.whileLocked {
            storage.buffer.clear()
        }
    }

    func close() {
        mutex.whileLocked {
            storage.closed = true
            sendCondition.broadcast()
            receiveCondition.broadcast()
        }
    }
}

extension BoundedChannel {

    mutating func next() -> Element? {
        return dequeue()
    }

}

extension BoundedChannel {

    var isClosed: Bool {
        return mutex.whileLocked { storage.closed }
    }

    var length: Int {
        return mutex.whileLocked {
            storage.buffer.count
        }
    }

    var isEmpty: Bool {
        storage.buffer.isEmpty
    }
}

extension BoundedChannel: Channel {}
