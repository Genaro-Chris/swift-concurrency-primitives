@propertyWrapper
@dynamicMemberLookup
final class Locker<Element>: @unchecked Sendable {

    let mutex: Mutex

    var value: Element

    var wrappedValue: Element {
        get {
            return updateWhileLocked { $0 }
        }
        set {
            updateWhileLocked { $0 = newValue }
        }
    }

    init(_ value: Element) {
        mutex = Mutex()
        self.value = value
    }

    func updateWhileLocked<T>(_ using: (inout Element) throws -> T) rethrows -> T {
        return try mutex.whileLocked {
            return try using(&value)
        }
    }

    convenience
    init(wrappedValue value: Element) {
        self.init(value)
    }

    var projectedValue: Locker<Element> {
        return self
    }
}

extension Locker {

    subscript<T>(dynamicMember memberKeyPath: KeyPath<Element, T>) -> T {
        updateWhileLocked { $0[keyPath: memberKeyPath] }
    }

    subscript<T>(dynamicMember memberKeyPath: WritableKeyPath<Element, T>) -> T {
        get {
            updateWhileLocked { $0[keyPath: memberKeyPath] }
        }
        set {
            updateWhileLocked { $0[keyPath: memberKeyPath] = newValue }
        }
    }

}

extension Locker where Element: AnyObject {

    subscript<T>(dynamicMember memberKeyPath: ReferenceWritableKeyPath<Element, T>) -> T {
        get {
            updateWhileLocked { $0[keyPath: memberKeyPath] }
        }
        set {
            updateWhileLocked { $0[keyPath: memberKeyPath] = newValue }
        }
    }
}
