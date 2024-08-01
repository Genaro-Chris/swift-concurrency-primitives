import Foundation

/// One sized buffered channel for multithreaded execution context which serves
/// as a communication mechanism between two or more threads
///
/// An enqueue operation on an unbuffered channel is synchronized before (and thus happens
/// before) the completion of a dequeue from that channel. A dequeue operation on an unbuffered channel
/// is synchronized before (and thus happens before) the completion of a corresponding or next enqueue operation
/// on that channel. In other words, if a thread enqueues a value into an unbuffered channel, the
/// receiving thread must complete the reception of that value before the next enqueue operation will happen
///
/// This is a multi-producer single-consumer concurrency primitives
/// where they are usually multiple senders and only one receiver useful for
/// message passing
///
/// This means at any given time it can only contain a single item in it and any more enqueue operations on
/// `UnbufferedChannel` with a value will block until a dequeue operation have finish its execution
@_spi(OtherChannels)
public struct UnbufferedChannel<Element> {

    private let storage: SingleItemStorage<Element>

    let mutex: Mutex

    let sendCondition: Condition

    let receiveCondition: Condition

    /// Initializes an instance of `UnbufferedChannel` type
    public init() {
        storage = SingleItemStorage()
        mutex = Mutex()
        sendCondition = Condition()
        receiveCondition = Condition()
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
            storage.value = item
            storage.receive = true
            storage.send = false
            receiveCondition.signal()
            return true
        }
    }

    public func dequeue() -> Element? {
        return mutex.whileLocked {
            guard !storage.closed else {
                let result: Element? = storage.value
                storage.value = nil
                return result
            }
            receiveCondition.wait(mutex: mutex, condition: storage.receive || storage.closed)
            let result: Element? = storage.value
            storage.value = nil
            if !storage.closed {
                storage.send = true
                storage.receive = false
            }
            sendCondition.signal()
            return result
        }
    }

    public func clear() {
        mutex.whileLockedVoid {
            storage.value = nil
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

extension UnbufferedChannel: IteratorProtocol, Sequence {

    public mutating func next() -> Element? {
        return dequeue()
    }

}

extension UnbufferedChannel {

    public var isClosed: Bool {
        return mutex.whileLocked { storage.closed }
    }

    public var length: Int {
        return mutex.whileLocked {
            switch storage.value {
            case .none: return 0
            case .some: return 1
            }
        }
    }

    public var isEmpty: Bool {
        return mutex.whileLocked {
            switch storage.value {
            case .none: return true
            case .some: return false
            }
        }
    }
}

extension UnbufferedChannel: Channel {}
