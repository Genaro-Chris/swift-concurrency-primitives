import Atomics
import Foundation

/// An unbounded blocking threadsafe construct for multithreaded execution context which serves 
/// as a communication mechanism between two or more threads
/// 
/// This means that it has an infinite sized buffer for storing enqueued items
/// in it. This also doesn't provide any form of synchronization between enqueueing and 
/// dequeuing items unlike the remaining kinds of ``Channel`` types
@frozen
public struct UnboundedChannel<Element> {

    @usableFromInline let buffer: Locked<Buffer<Element>>

    @usableFromInline let closed: ManagedAtomic<Bool>

    @usableFromInline let bufferCount: ManagedAtomic<Int>

    /// Initializes an instance of `UnboundedChannel` type
    public init() {
        buffer = Locked(Buffer())
        closed = ManagedAtomic(false)
        bufferCount = ManagedAtomic(0)
    }

    @inlinable
    public func enqueue(_ item: Element) -> Bool {
        guard !closed.load(ordering: .relaxed) else {
            return false
        }
        buffer.updateWhileLocked { $0.enqueue(item) }
        return true
    }

    @inlinable
    public func dequeue() -> Element? {
        switch (closed.load(ordering: .relaxed), isEmpty) {
        case (true, false):
            return buffer.updateWhileLocked { $0.dequeue() }
        case (true, true): return nil
        default: ()
        }

        while isEmpty {
            switch (closed.load(ordering: .relaxed), isEmpty) {
            case (true, false):
                return buffer.updateWhileLocked { $0.dequeue() }
            case (true, true): return nil
            default: Thread.yield()
            }

        }
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

extension UnboundedChannel {

    public mutating func next() -> Element? {
        return dequeue()
    }

}

extension UnboundedChannel {

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

extension UnboundedChannel: Channel {}
