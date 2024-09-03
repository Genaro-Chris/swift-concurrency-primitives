final class LockBuffer<Value>: ManagedBuffer<Mutex, Value> {

    static func create(value: Value) -> Self {
        let buffer = Self.create(minimumCapacity: 1) { buffer in
            buffer.withUnsafeMutablePointerToElements { valuePtr in
                valuePtr.initialize(to: value)
            }
            return Mutex()
        }

        let storage = unsafeDowncast(buffer, to: Self.self)

        return storage
    }

    deinit {
        self.withUnsafeMutablePointerToElements { value in
            // This ensures the element's pointee instance deinitializer is called
            _ = value.move()
        }
    }

    func interactWhileLocked<V>(_ body: (inout Value, Mutex) throws -> V) rethrows -> V {
        return try self.withUnsafeMutablePointerToElements { value in
            try self.header.whileLocked {
                try body(&value.pointee, self.header)
            }
        }
    }
}

final class ConditionalLockBuffer<Value>: ManagedBuffer<ConditionLock, Value> {

    static func create(value: Value) -> Self {
        let buffer = Self.create(minimumCapacity: 1) { buffer in
            buffer.withUnsafeMutablePointerToElements { valuePtr in
                valuePtr.initialize(to: value)
            }
            return ConditionLock()
        }

        let storage = unsafeDowncast(buffer, to: Self.self)

        return storage
    }

    deinit {
        self.withUnsafeMutablePointerToElements { value in
            // This ensures the element's pointee instance deinitializer is called
            _ = value.move()
        }
    }

    func interactWhileLocked<V>(_ body: (inout Value, ConditionLock) -> V) -> V {
        return self.withUnsafeMutablePointerToElements { value in
            self.header.whileLocked {
                body(&value.pointee, self.header)
            }
        }
    }
}
