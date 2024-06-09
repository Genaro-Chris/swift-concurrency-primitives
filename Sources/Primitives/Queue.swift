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
/// await withTaskGroup(of: Void.self) { group in
///     for _ in 1 ... 5 {
///         group.addTask {
///             // perform some operation
///             queue <- (Int.random(in: 0 ... 1000))
///         }
///     }
/// }
///
/// while let value = queue.dequeue() {
///     print("\(value)")
/// }
/// ```
public struct Queue<Element> {

    final class Storage {

        var buffer: Deque<Element>

        init() {
            buffer = Deque()
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

    let storage: Storage

    let lock: Lock

    /// Initializes an instance of the `Queue` type
    public init() {
        storage = Storage()
        lock = Lock()
    }

    /// Enqueue an item into the queue
    /// - Parameter item: item to be enqueued
    public func enqueue(_ item: Element) {
        lock.whileLocked { storage.enqueue(item) }
    }

    /// Dequeues an item from the queue
    /// - Returns: an item or nil if the queue is empty
    public func dequeue() -> Element? {
        return lock.whileLocked { storage.dequeue() }
    }

    /// Clears the remaining enqueued items
    public func clear() {
        lock.whileLocked { storage.clear() }
    }
}

extension Queue {

    /// Enqueues an item into a `Queue` instance
    public static func <- (this: Queue, value: Element) {
        this.enqueue(value)
    }

    /// Dequeues an item from a `Queue` instance
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
