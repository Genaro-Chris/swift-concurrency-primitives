import Atomics
import Foundation

/// A buffered blocking threadsafe construct for multithreaded execution context which serves as a communication mechanism between two or more threads
/// 
/// A fixed size buffer channel which means at any given time it can only contain a certain number of items in it, it 
/// blocks on the sender's side if the buffer has reached that certain number
@_spi(OtherChannels)
@frozen
public struct BoundedChannel<Element> {

    @usableFromInline let buffer: Locked<Buffer<Element>>

    @usableFromInline let closed: ManagedAtomic<Bool>

    @usableFromInline let readyToSend: ManagedAtomic<Bool>

    @usableFromInline let bufferCount: ManagedAtomic<Int>

    /// Maximum number of stored items at any given time
    public let capacity: Int

    /// Initializes an instance of `BoundedChannel` type
    /// - Parameter size: maximum capacity of the channel
    /// - Returns: nil if the `size` argument is less than one
    public init?(size: Int) {
        guard size > 0 else {
            return nil
        }
        buffer = Locked(Buffer())
        buffer.updateWhileLocked { $0.buffer.reserveCapacity(size) }
        closed = ManagedAtomic(false)
        readyToSend = ManagedAtomic(true)
        bufferCount = ManagedAtomic(0)
        capacity = size
    }

    @inlinable
    public func enqueue(_ item: Element) -> Bool {
        guard !closed.load(ordering: .relaxed) else {
            return false
        }
        while !readyToSend.weakCompareExchange(
            expected: true, desired: true, ordering: .acquiringAndReleasing
        ).exchanged {
            if closed.load(ordering: .relaxed) {
                return false
            }
            Thread.yield()
        }

        if bufferCount.wrappingIncrementThenLoad(ordering: .acquiringAndReleasing)
            == capacity {
            _ = readyToSend.exchange(false, ordering: .acquiringAndReleasing)
        }

        buffer.updateWhileLocked { $0.enqueue(item) }
        return true
    }

    @inlinable
    public func dequeue() -> Element? {
        switch (closed.load(ordering: .relaxed), isEmpty) {
        case (true, false):
            readyToSend.store(true, ordering: .releasing)
            bufferCount.wrappingDecrement(ordering: .acquiringAndReleasing)
            return buffer.updateWhileLocked { $0.dequeue() }
        case (true, true): return nil
        default: ()
        }

        while isEmpty {
            switch (closed.load(ordering: .relaxed), isEmpty) {
            case (true, false):
                readyToSend.store(true, ordering: .releasing)
                bufferCount.wrappingDecrement(ordering: .acquiringAndReleasing)
                return buffer.updateWhileLocked { $0.dequeue() }
            case (true, true): return nil
            default: Thread.yield()
            }
        }

        readyToSend.store(true, ordering: .relaxed)
        bufferCount.wrappingDecrement(ordering: .acquiringAndReleasing)
        return buffer.updateWhileLocked { $0.dequeue() }
    }

    public func clear() {
        buffer.updateWhileLocked { $0.clear() }
    }

    public func close() {
        guard !closed.load(ordering: .relaxed) else {
            return
        }
        closed.store(true, ordering: .relaxed)
    }
}

extension BoundedChannel {

    public mutating func next() -> Element? {
        return dequeue()
    }

}

extension BoundedChannel {

    public var isClosed: Bool {
        closed.load(ordering: .relaxed)
    }

    public var length: Int {
        return buffer.count
    }

    public var isEmpty: Bool {
        return buffer.isEmpty
    }
}

extension BoundedChannel: Channel {}
