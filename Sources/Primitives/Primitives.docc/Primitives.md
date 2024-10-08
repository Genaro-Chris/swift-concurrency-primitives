# Primitives

A concurrency primitive package written in swift for swift developers

## Overview

This package provides various basic concurrency primitives such as ``Lock`` which is similar to `Mutex` in other languages, ``Locked``, ``ThreadPool``, ``Channel``, ``ThreadParker`` and ``Queue``. This package aims to provide concurrency primitives that are readily available in other programming languages but not in swift.

Most of the constructs shouldn't be used in async context because they block a thread's execution flow thereby violating the swift's runtime contract: forward progress of thread execution.

This package serves as an alternative to the ``Dispatch`` module of the swift language with a few more concurrency constructs.

## Topics

### Synchronization 

This package also provides some constructs that synchronize concurrent accesses to a critical code section in order to avoid data race bugs

- ``Lock``
- ``Locked``

### Threads Co-ordination

This package even provide some constructs for threads co-ordination by waiting for all threads to finish their execution

- ``LockSemaphore``
- ``WaitGroup``
- ``ThreadParker``


### Message Passing 

This package provides some concurrency constructs that enable threads share memory by communicating values as message.


- ``Queue``
- ``OneShotChannel``
- ``UnboundedChannel``

### ThreadPool

This package provides some concurrency constructs that efficiently manage a fized size of worker threads ready to execute code. 

- ``WorkerThread``
- ``WorkerPool``

### Call Once

A synchronization primitive which provides a way of executing code exactly once regardless of how many times it was called in a thread-safe manner

- ``Once``
- ``OnceState``