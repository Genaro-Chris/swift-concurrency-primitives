@usableFromInline
@dynamicMemberLookup
final class Box<Value> {

    @usableFromInline var innerValue: Value

    init(_ value: Value) {
        innerValue = value
    }

    @usableFromInline
    func interact<V>(with: (inout Value) throws -> V) rethrows -> V {
        return try with(&innerValue)
    }

    @usableFromInline
    subscript<T>(dynamicMember memberKeyPath: KeyPath<Value, T>) -> T {
        innerValue[keyPath: memberKeyPath]
    }

    @usableFromInline
    subscript<T>(dynamicMember memberKeyPath: WritableKeyPath<Value, T>) -> T {
        get {
            innerValue[keyPath: memberKeyPath]
        }
        set {
            innerValue[keyPath: memberKeyPath] = newValue
        }
    }

}

extension Box where Value: AnyObject {

    @usableFromInline
    subscript<T>(dynamicMember memberKeyPath: ReferenceWritableKeyPath<Value, T>) -> T {
        get {
            innerValue[keyPath: memberKeyPath]
        }
        set {
            innerValue[keyPath: memberKeyPath] = newValue
        }
    }
}
