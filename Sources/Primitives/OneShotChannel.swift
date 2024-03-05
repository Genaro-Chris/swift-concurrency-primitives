import Atomics
import Foundation

/// A single use blocking threadsafe construct for multithreaded execution context which serves 
/// as a communication mechanism between two threads
/// 
/// This is useful in scenarios where a developer needs to send just a value safely across 
/// miltithreaded context
/// 
/// # Example
/// 
/// ```swift
/// func getIntAsync() async -> Int {
///     // perform some operation
///     return Int.random(in: 0 ... 1000)
/// }
/// 
/// let channel = OneShotChannel<Int>()
/// Task.detached { 
/// // This should be done on a detached task to avoid blocking the caller thread
///     channel <- (await getIntAsync())
/// }
/// // do other work
/// if let value = <-channel {
///    print("Got \(value)")
/// }
/// ```
@frozen
public struct OneShotChannel<Element> {

    @usableFromInline let buffer: Locked<Element?>

    @usableFromInline let readyToSend: ManagedAtomic<Int>

    /// Initializes an instance of `OneShotChannel` type
    public init() {
        buffer = Locked(nil)
        readyToSend = ManagedAtomic(0)
    }

    @inlinable
    public func enqueue(_ item: Element) -> Bool {
        guard readyToSend.load(ordering: .relaxed) < 1 else {
            return false
        }
        buffer.updateWhileLocked { $0 = item }
        readyToSend.store(1, ordering: .releasing)
        return true
    }

    @inlinable
    public func dequeue() -> Element? {
        guard readyToSend.load(ordering: .relaxed) < 2 else {
            return nil
        }
        while !readyToSend.weakCompareExchange(
            expected: 1, desired: 2, ordering: .acquiringAndReleasing
        ).exchanged {
            if readyToSend.load(ordering: .relaxed) == 2 {
                return nil
            }
            Thread.yield()
        }
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
        readyToSend.store(2, ordering: .relaxed)
    }
}

extension OneShotChannel {

    public mutating func next() -> Element? {
        return dequeue()
    }

}

extension OneShotChannel {

    public var isClosed: Bool {
        readyToSend.load(ordering: .relaxed) == 2
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

extension OneShotChannel: Channel {}
