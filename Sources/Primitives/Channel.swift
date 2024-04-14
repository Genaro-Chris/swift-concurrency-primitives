/// A blocking threadsafe construct for multithreaded execution context which serves
/// as a message passing communication mechanism between two or more threads
///
/// This construct provides a multi-producer single-consumer concurrency primitives
/// where they are usually multiple senders and only one receiver useful for
/// message passing
///
/// This construct blocks a thread on either the sending or receiving parts so it is
/// highly advised to avoid using together with the Swift modern concurrency that is in async-await contexts
/// because it blocks tasks from making forward progress
public protocol Channel<Element>: IteratorProtocol, Sequence {
    associatedtype Element

    /// Indicates if `Channel` is closed
    var isClosed: Bool { get }

    /// Indicates if `Channel` instance is empty or not
    var isEmpty: Bool { get }

    /// Number of items in the `Channel` instance
    var length: Int { get }

    /// Enqueues an item into the `Channel` instance
    /// - Parameter item: item to be enqueued
    /// - Returns: true if sent otherwise false
    func enqueue(_ item: Element) -> Bool

    /// Dequeues an item from the `Channel` instance
    ///  while blocking the current thread
    /// - Returns: an item or nil if the `Channel` instance is closed
    /// that is by calling it's `close` method
    func dequeue() -> Element?

    /// Clears the remaining enqueued items
    func clear()

    /// Closes both the sending and receiving part of the `Channel` instance
    func close()
}

extension Channel {

    /// Enqueues an item into a `Channel` instance
    public static func <- (channel: Self, value: Element) {
        _ = channel.enqueue(value)
    }

    /// Dequeues an item from the `Channel` instance
    public static prefix func <- (channel: Self) -> Element? {
        return channel.dequeue()
    }
}

/// Enqueues an item into a `Channel` instance
public func <- <Element, ChannelType>(channel: ChannelType, value: Element)
where ChannelType: Channel, ChannelType.Element == Element {
    _ = channel.enqueue(value)
}

/// Dequeues an item from the `Channel` instance
public prefix func <- <Element, ChannelType>(channel: ChannelType) -> Element?
where ChannelType: Channel, ChannelType.Element == Element {
    return channel.dequeue()
}
