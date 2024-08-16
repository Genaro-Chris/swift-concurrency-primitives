/// A nonblocking threadsafe construct for multithreaded execution context which serves
/// as a message passing communication mechanism between two or more threads
///
/// This construct is useful in sending values across `Thread` or `DispatchQueue`
/// in a safe and data race free way
///
/// # Example
///
/// ```swift
/// let queue = Queue<Int>()
/// DispatchQueue.concurrentPerform(iterations: 10) { [queue] index in
///     // perform some operation
///     queue <- index
/// }
///
/// while let value = queue.dequeue() {
///     print("\(value)")
/// }
/// ```
public struct Queue<Element> {

    private let storageLock: LockBuffer<Storage<Element>>

    /// Initialises an instance of the `Queue` type
    public init() {
        storageLock = LockBuffer.create(value: Storage())
    }

    /// Enqueue an item into the queue
    /// - Parameter item: item to be enqueued
    public func enqueue(item: Element) {
        storageLock.interactWhileLocked { storage, _ in storage.enqueue(item) }
    }

    /// ContiguousArrayues an item from the queue
    /// - Returns: an item or nil if the queue is empty
    public func dequeue() -> Element? {
        return storageLock.interactWhileLocked { storage, _ in storage.dequeue() }
    }

    /// Clears the remaining enqueued items
    public func clear() {
        storageLock.interactWhileLocked { storage, _ in storage.clear() }
    }
}

extension Queue {

    /// Enqueues an item into a `Queue` instance
    public static func <- (this: Queue, value: Element) {
        this.enqueue(item: value)
    }

    /// Dequeues an item from a `Queue` instance
    public static prefix func <- (this: Queue) -> Element? {
        this.dequeue()
    }

    /// Number of items in the `Queue` instance
    public var length: Int {
        return storageLock.interactWhileLocked { storage, _ in storage.count }
    }

    /// Indicates if `Queue` instance is empty or not
    public var isEmpty: Bool {
        return storageLock.interactWhileLocked { storage, _ in storage.isEmpty }
    }
}
