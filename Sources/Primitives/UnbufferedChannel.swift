import Atomics
import Foundation

/// One sized buffered channel for multithreaded execution context which serves
/// as a communication mechanism between two or more threads
///
/// An enqueue operation on an unbuffered channel is synchronized before (and thus happens
/// before) the completion of a dequeue from that channel. A dequeue operation on an unbuffered channel
/// is synchronized before (and thus happens before) the completion of a corresponding or next enqueue operation
/// on that channel. In other words, if a thread enqueues a value through an unbuffered channel, the
/// receiving thread will complete the reception of that value, and then the enqueueing thread will
/// finish enqueueing that value.
///
/// This means at any given time it can only contain a single item in it and any more enqueue operations on
/// `UnbufferedChannel` with a value will block until a dequeue operation have being done
@_spi(OtherChannels)
@frozen
@_eagerMove
public struct UnbufferedChannel<Element> {

    @usableFromInline final class _Storage<Value> {

        init() {
            innerValue = nil

            send = true

            receive = false

            closed = false
        }

        private var innerValue: Value?

        var value: Value? {
            _read {
                yield innerValue
            }
            _modify {
                yield &innerValue
            }
        }

        var send: Bool

        var receive: Bool

        var closed: Bool

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

    let mutex: Mutex

    let sendCondition: Condition

    let receiveCondition: Condition

    /// Initializes an instance of `UnbufferedChannel` type
    public init() {
        storage = _Storage()
        mutex = Mutex()
        sendCondition = Condition()
        receiveCondition = Condition()
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
                let result = storage.value
                storage.value = nil
                return result
            }
            receiveCondition.wait(mutex: mutex, condition: storage.receiveReady)
            let result = storage.value
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
        mutex.whileLocked {
            storage.value = nil
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

extension UnbufferedChannel {

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
