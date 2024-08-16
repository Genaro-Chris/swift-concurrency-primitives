/// A single item storage class for ``Channel`` types
final class SingleItemStorage<Value> {

    var value: Value?

    var send: Bool

    var receive: Bool

    var closed: Bool

    init() {
        value = nil

        send = true

        receive = false

        closed = false
    }

}
