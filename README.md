# swift-concurrency-primitives


[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0) 
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FGenaro-Chris%2Fswift-concurrency-primitives%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/Genaro-Chris/swift-concurrency-primitives)
<img src="https://img.shields.io/badge/platforms-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey.svg" />

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

- [Lock](https://swiftpackageindex.com/Genaro-Chris/swift-concurrency-primitives/main/documentation/primitives/lock)
- [Locked](https://swiftpackageindex.com/Genaro-Chris/swift-concurrency-primitives/main/documentation/primitives/locked)
  
### Threads Co-ordination

This package even provide some constructs for co-ordination for threads by waiting for all threads to finish their execution

- [Notifier](https://swiftpackageindex.com/Genaro-Chris/swift-concurrency-primitives/main/documentation/primitives/notifier)
- [WaitGroup](https://swiftpackageindex.com/Genaro-Chris/swift-concurrency-primitives/main/documentation/primitives/waitgroup)


### Message Passing 

This package provides some concurrency constructs that enable threads share memory by communicating values as message.

- [Queue](https://swiftpackageindex.com/Genaro-Chris/swift-concurrency-primitives/main/documentation/primitives/queue)
- [OneShotChannel](https://swiftpackageindex.com/Genaro-Chris/swift-concurrency-primitives/main/documentation/primitives/oneshotchannel)
- [UnboundedChannel](https://swiftpackageindex.com/Genaro-Chris/swift-concurrency-primitives/main/documentation/primitives/unboundedchannel)  

### ThreadPool

This package provides some concurrency construct that efficiently manage a fized size of worker threads ready to execute code.

- [WorkerThread](https://swiftpackageindex.com/Genaro-Chris/swift-concurrency-primitives/main/documentation/primitives/singlethread)
- [WorkerPool](https://swiftpackageindex.com/Genaro-Chris/swift-concurrency-primitives/main/documentation/primitives/WorkerPool)

### Call Once

A synchronization primitive which provides a way of executing code exactly once regardless of how many times it was called in a thread-safe manner

- [Once](https://swiftpackageindex.com/Genaro-Chris/swift-concurrency-primitives/main/documentation/primitives/once)
- [OnceState](https://swiftpackageindex.com/Genaro-Chris/swift-concurrency-primitives/main/documentation/primitives/oncestate)

And many more others

## Documentation

The full API documentation can be accessed [here](https://swiftpackageindex.com/Genaro-Chris/swift-concurrency-primitives/main/documentation)

## ExampleUsage

For some practical usage for this package, take a good look at [ExampleApp](ExampleApp)

## Contributing

I highly welcome and encourage all sorts of contributions from all developers.

## License
This package is released under Apache-2.0 license. See [LICENSE](LICENSE.txt) for more information.

