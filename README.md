# swift-concurrency-primitives

A concurrency primitive package written in swift for swift developers

# Overview

This package provides various basic concurrency primitives such as `Lock`, `Locked` which is similar to `Mutex` in other languages, `ThreadPool`, `Channel` and `Queue`.
This package aims to provide concurrency primitives that are readily available in other programming languages but not in swift.

# Installation

To use this package

First, add the following package dependency to your `package.swift` file

```swift
.package(url: "https://github.com/Genaro-Chris/swift-concurrency-primitives", branch: "main")
```

Then add the `Primitives` library to the target(s) you want to use it

```swift
.product(name: "Primitives", package: "swift-concurrency-primitives")
```

# Features

This package provides various basic concurrency primitives which can be categorized into the following

- [Synchronization](README.md#synchronization)
- [Thread Coordination](README.md#threads-co-ordination)
- [Message Passing](README.md#message-passing)
- [ThreadPool](README.md#threadpool)
- [Call Once](README.md#call-once)


### Synchronization 

This package also provides some constructs that synchronize concurrent accesses to a critical code section in order to avoid data race bugs

- [Lock](https://swiftpackageindex.com/Genaro-Chris/swift-concurrency-primitives/main/documentation/lock)
- [Locked](https://swiftpackageindex.com/Genaro-Chris/swift-concurrency-primitives/main/documentation/locked)
  
### Threads Co-ordination

This package even provide some constructs for co-ordination for threads by waiting for all threads to finish their execution

- [Notifier](https://swiftpackageindex.com/Genaro-Chris/swift-concurrency-primitives/main/documentation/notifier)
- [WaitGroup](https://swiftpackageindex.com/Genaro-Chris/swift-concurrency-primitives/main/documentation/waitgroup)


### Message Passing 

This package provides some concurrency constructs that enable threads share memory by communicating values as message.

- [Queue](https://swiftpackageindex.com/Genaro-Chris/swift-concurrency-primitives/main/documentation/queue)
- [OneShotChannel](https://swiftpackageindex.com/Genaro-Chris/swift-concurrency-primitives/main/documentation/oneshotchannel)
- [UnboundedChannel](https://swiftpackageindex.com/Genaro-Chris/swift-concurrency-primitives/main/documentation/unboundedchannel)  

### ThreadPool

This package provides some concurrency construct that efficiently manage a fized size of worker threads ready to execute code.

- [SingleThread](https://swiftpackageindex.com/Genaro-Chris/swift-concurrency-primitives/main/documentation/singlethread)
- [MultiThreadedPool](https://swiftpackageindex.com/Genaro-Chris/swift-concurrency-primitives/main/documentation/multithreadedpool)

### Call Once

A synchronization primitive which provides a way of executing code exactly once regardless of how many times it was called in a thread-safe manner

- [Once](https://swiftpackageindex.com/Genaro-Chris/swift-concurrency-primitives/main/documentation/once)
- [OnceState](https://swiftpackageindex.com/Genaro-Chris/swift-concurrency-primitives/main/documentation/oncestate)

And many more others

## Documentation

The full API documentation can be accessed [here](https://swiftpackageindex.com/Genaro-Chris/swift-concurrency-primitives/main/documentation)

## ExampleUsage

For some practical usage for this package, take a good look at [ExampleApp](ExampleApp)

## Contributing

I highly welcome and encourage all sorts of contributions from all developers.

## License
This package is released under Apache-2.0 license. See [LICENSE](LICENSE.txt) for more information.

