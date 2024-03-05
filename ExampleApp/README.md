# Example App

This is a sample app that showcasing the powers of [swift-concurrency-primitives](https://github.com/Genaro-Chris/swift-concurrency-primitives) package.

In this application, by tweaking the ``CustomGlobalExecutor`` class initializer in [CustomGlobalExecutor.swift](Sources/GlobalExecutor.swift) file you can replace swift's default global concurrency hook with a custom one with any number of threads of your choice by using the appropriate `ThreadPool` type.
