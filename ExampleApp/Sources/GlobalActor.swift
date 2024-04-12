import Foundation
import Primitives

/// Sample global actor that uses the `LockCustomExecutor` as its SerialExecutor
@globalActor actor GlobalActor {

    let executor = LockCustomExecutor()

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        UnownedSerialExecutor(ordinary: executor)
    }

    static let shared = GlobalActor()
}
