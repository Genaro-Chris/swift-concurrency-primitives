import Atomics
import Foundation

/// This waits for a number of threads or tasks to finish.
///
/// The caller threads calls ``enter()`` a number of times to set the number of
/// threads to wait for. Then each of the threads or tasks
/// runs and calls ``done()`` when finished. Then,
/// ``waitForAll()`` can be used to block until all threads have finished.
/// 
/// This is similar to Go's [sync.WaitGroup](https://pkg.go.dev/sync#WaitGroup)
/// and Swift's [DispatchGroup](https://developer.apple.com/documentation/dispatch/dispatchgroup)
/// 
/// # Example
/// 
/// ```swift
/// let waitGroup = WaitGroup()
/// for _ in 1...5 {
///     waitGroup.enter()
///     Task.detached {
///         defer {
///             waitGroup.done()    
///         }
///         // do some async or concurrent work
///     }
/// }
/// waitGroup.waitForAll()
/// ```
@frozen
public struct WaitGroup {

    @usableFromInline let index: ManagedAtomic<Int>

    /// Initializes a `WaitGroup` instance
    @inlinable
    public init() {
        index = ManagedAtomic(0)
    }

    /// This indicates that a new thread or task is about to start.
    /// This should be called only outside the thread or task
    @inlinable
    public func enter() {
        index.wrappingIncrement(ordering: .acquiringAndReleasing)
    }

    /// Indicates that it is done executing this thread.
    /// This should be called only in the thread or task
    @inlinable
    public func done() {
        index.wrappingDecrement(ordering: .acquiringAndReleasing)
    }

    /// Blocks until there is no more thread running
    @inlinable
    public func waitForAll() {
        while index.load(ordering: .acquiring) != 0 {
            Thread.yield()
        }
    }
}
