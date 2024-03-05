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
public struct UnbufferedChannel<Element> {

    @usableFromInline let buffer: Locked<Element?>

    @usableFromInline let closed: ManagedAtomic<Bool>

    @usableFromInline let readyToSend: ManagedAtomic<Int>

    /// Initializes an instance of `UnbufferedChannel` type
    public init() {
        buffer = Locked(nil)
        closed = ManagedAtomic(false)
        readyToSend = ManagedAtomic(0)
    }

    @inlinable
    public func enqueue(_ item: Element) -> Bool {
        guard !closed.load(ordering: .relaxed) else {
            return false
        }
        while !readyToSend.weakCompareExchange(
            expected: 0, desired: 2, ordering: .acquiringAndReleasing
        ).exchanged {
            if closed.load(ordering: .relaxed) {
                return false
            }
            Thread.yield()
        }
        defer { readyToSend.store(1, ordering: .releasing) }
        buffer.updateWhileLocked { $0 = item }
        return true
    }

    @inlinable
    public func dequeue() -> Element? {
        guard !closed.load(ordering: .relaxed) else {
            return nil
        }

        while !readyToSend.weakCompareExchange(
            expected: 1, desired: 3, ordering: .acquiringAndReleasing
        ).exchanged {
            if closed.load(ordering: .relaxed) {
                return nil
            }
            Thread.yield()
        }

        defer { readyToSend.store(0, ordering: .releasing) }
        return buffer.updateWhileLocked {
            let result = $0
            $0 = nil
            return result
        }
    }

    public func clear() {
        buffer.updateWhileLocked { $0 = nil }
    }

    public func close() {
        guard !closed.load(ordering: .relaxed) else {
            return
        }
        closed.store(true, ordering: .relaxed)
    }
}

extension UnbufferedChannel {

    public mutating func next() -> Element? {
        return dequeue()
    }

}

extension UnbufferedChannel {

    public var isClosed: Bool {
        closed.load(ordering: .relaxed)
    }

    public var length: Int {
        return buffer.updateWhileLocked {
            switch $0 {
            case .none: return 0
            case .some: return 1
            }
        }
    }

    public var isEmpty: Bool {
        return buffer.updateWhileLocked {
            switch $0 {
            case .none: return true
            case .some: return false
            }
        }
    }
}

extension UnbufferedChannel: Channel {}
