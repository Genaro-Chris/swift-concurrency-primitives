final class LockBuffer<Value>: ManagedBuffer<Value, Mutex> {

    static func create(value: Value) -> Self {
        let buffer = Self.create(minimumCapacity: 1) { buffer in
            buffer.withUnsafeMutablePointers { _, lockPtr in
                lockPtr.initialize(to: Mutex())
            }
            return value
        }

        let storage = unsafeDowncast(buffer, to: Self.self)

        return storage
    }

    deinit {
        self.withUnsafeMutablePointerToElements { lock in
            _ = lock.move()
        }
    }

    func interactWhileLocked<V>(_ body: (inout Value, Mutex) throws -> V) rethrows -> V {
        return try self.withUnsafeMutablePointers { header, lock in
            try lock.pointee.whileLocked {
                try body(&header.pointee, lock.pointee)
            }
        }
    }
}

final class ConditionalLockBuffer<Value>: ManagedBuffer<Value, ConditionLock> {

    static func create(value: Value) -> Self {
        let buffer = Self.create(minimumCapacity: 1) { buffer in
            buffer.withUnsafeMutablePointers { _, lockPtr in
                lockPtr.initialize(to: ConditionLock())
            }
            return value
        }

        let storage = unsafeDowncast(buffer, to: Self.self)

        return storage
    }

    deinit {
        self.withUnsafeMutablePointerToElements { lock in
            _ = lock.move()
        }
    }

    func interactWhileLocked<V>(_ body: (inout Value, ConditionLock) -> V) -> V {
        return self.withUnsafeMutablePointers { header, lock in
            lock.pointee.whileLocked {
                body(&header.pointee, lock.pointee)
            }
        }
    }
}
