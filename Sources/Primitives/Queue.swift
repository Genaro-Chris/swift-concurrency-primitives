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

    private let storage: Storage<Element>

    let lock: Lock

    /// Initializes an instance of the `Queue` type
    public init() {
        storage = Storage()
        lock = Lock()
    }

    /// Enqueue an item into the queue
    /// - Parameter item: item to be enqueued
    public func enqueue(item: Element) {
        lock.whileLockedVoid { storage.enqueue(item) }
    }

    /// ContiguousArrayues an item from the queue
    /// - Returns: an item or nil if the queue is empty
    public func dequeue() -> Element? {
        return lock.whileLocked { storage.dequeue() }
    }

    /// Clears the remaining enqueued items
    public func clear() {
        lock.whileLockedVoid { storage.clear() }
    }
}

extension Queue {

    /// Enqueues an item into a `Queue` instance
    public static func <- (this: Queue, value: Element) {
        this.enqueue(item: value)
    }

    /// ContiguousArrayues an item from a `Queue` instance
    public static prefix func <- (this: Queue) -> Element? {
        this.dequeue()
    }

    /// Number of items in the `Queue` instance
    public var length: Int {
        return lock.whileLocked { storage.count }
    }

    /// Indicates if `Queue` instance is empty or not
    public var isEmpty: Bool {
        return lock.whileLocked { storage.isEmpty }
    }
}

private final class Storage<Element> {

    var buffer: ContiguousArray<Element>

    init() {
        buffer = ContiguousArray()
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
